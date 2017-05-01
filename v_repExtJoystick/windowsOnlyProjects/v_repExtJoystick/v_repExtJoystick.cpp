// V-REP plugin "Joystick" by Eric Rohmer, December 2011

#include "stdafx.h"
#include "v_repExtJoystick.h"
#include "v_repLib.h"
#include <iostream>
#include <sstream>
#include <shlwapi.h> // for the "PathRemoveFileSpec" function

namespace v_repExtJoystick {

	namespace {  // private namespace

		volatile bool _joyThreadLaunched = false;
		volatile bool _joyThreadEnded = false;
		volatile bool _inJoyThread = false;
		volatile bool joyGoodToRead = false;
		LPDIRECTINPUT8 di;

		HWND winHandle = nullptr;
		Joystick joysticks[4];
		int currentDeviceIndex = 0;
		int joystickCount = 0;

		std::string HRESULTToString(HRESULT hr) {
			// https://msdn.microsoft.com/en-us/library/windows/desktop/microsoft.directx_sdk.idirectinputdevice8.idirectinputdevice8.setproperty(v=vs.85).aspx
			std::string str = "INVALID_RESULT";
			switch (hr)
			{
			case DI_OK: str = "DI_OK";					break;
			case DI_PROPNOEFFECT: str = "DI_PROPNOEFFECT";		break;
			case DIERR_INVALIDPARAM: str = "DIERR_INVALIDPARAM";		break;
			case DIERR_NOTINITIALIZED: str = "DIERR_NOTINITIALIZED";	break;
			case DIERR_OBJECTNOTFOUND: str = "DIERR_OBJECTNOTFOUND";	break;
			case DIERR_UNSUPPORTED: str = "DIERR_UNSUPPORTED";		break;
			default:
				std::stringstream stream;
				//stream << std::hex << hr;
				stream << std::hex << hr;
				str = stream.str();
				break;
			}
			return str;
		}

		BOOL CALLBACK enumCallback(const DIDEVICEINSTANCE* instance, VOID* context)
		{
			HRESULT hr;
			hr = di->CreateDevice(instance->guidInstance, &joysticks[currentDeviceIndex].handle, nullptr);
			if (FAILED(hr))
				return DIENUM_CONTINUE;

			joysticks[currentDeviceIndex].id = currentDeviceIndex;
			currentDeviceIndex++;

			return DIENUM_CONTINUE;
		}

		BOOL CALLBACK enumAxesCallback(const DIDEVICEOBJECTINSTANCE* instance, VOID* context)
		{
			HWND hDlg = (HWND)context;

			DIPROPRANGE propRange;
			propRange.diph.dwSize = sizeof(DIPROPRANGE);
			propRange.diph.dwHeaderSize = sizeof(DIPROPHEADER);
			propRange.diph.dwHow = DIPH_BYID;
			propRange.diph.dwObj = instance->dwType;
			propRange.lMin = -1000;
			propRange.lMax = +1000;

			// Set the range for the axis
			if (FAILED(joysticks[currentDeviceIndex].handle->SetProperty(DIPROP_RANGE, &propRange.diph))) {
				return DIENUM_STOP;
			}

			// Counts num of forcefeedback enables axes
			auto pdwNumForceFeedbackAxis = reinterpret_cast<DWORD*>(context);
			if ((instance->dwFlags & DIDOI_FFACTUATOR) != 0)
				joysticks[currentDeviceIndex].num_force_axes++;

			return DIENUM_CONTINUE;
		}

		INT normalizedForceToDInputForce(float nforce) {
			INT force = (INT)(nforce*DI_FFNOMINALMAX);

			// Keep force within bounds
			if (force < -DI_FFNOMINALMAX)
				force = -DI_FFNOMINALMAX;

			if (force > +DI_FFNOMINALMAX)
				force = +DI_FFNOMINALMAX;

			return force;
		}

		bool setJoyForces(Joystick& joy) {
			INT xforce = normalizedForceToDInputForce(joy.forces[0]);
			INT yforce = normalizedForceToDInputForce(joy.forces[1]);

			// Modifying an effect is basically the same as creating a new one, except
			// you need only specify the parameters you are modifying
			LONG rglDirection[2] = { 0, 0 };
			DICONSTANTFORCE cf;

			if (joy.num_force_axes == 1)
			{
				// If only one force feedback axis, then apply only one direction and 
				// keep the direction at zero
				cf.lMagnitude = xforce;
				rglDirection[0] = 0;
			}
			else
			{
				// If two force feedback axis, then apply magnitude from both directions 
				rglDirection[0] = xforce;
				rglDirection[1] = yforce;
				cf.lMagnitude = (DWORD)sqrt((double)xforce * xforce +
					(double)yforce * (double)yforce);
			}

			//printf("Setting force to (x = %d, y = %d, mag = %d).\n", rglDirection[0], rglDirection[1], cf.lMagnitude);

			DIEFFECT eff;
			ZeroMemory(&eff, sizeof(eff));
			eff.dwSize = sizeof(DIEFFECT);
			eff.dwFlags = DIEFF_CARTESIAN | DIEFF_OBJECTOFFSETS;
			eff.cAxes = joy.num_force_axes;
			eff.rglDirection = rglDirection;
			eff.lpEnvelope = 0;
			eff.cbTypeSpecificParams = sizeof(DICONSTANTFORCE);
			eff.lpvTypeSpecificParams = &cf;
			eff.dwStartDelay = 0;

			// Now set the new parameters and start the effect immediately.
			if (FAILED(joy.force_effect->SetParameters(&eff, DIEP_DIRECTION |
				DIEP_TYPESPECIFICPARAMS |
				DIEP_START))) {
				printf("Failed at 'joy.force_effect->SetParameters'.\n");
				return false;
			}

			return true;
		}

		DWORD WINAPI _joyThread(LPVOID lpParam)
		{
			_inJoyThread = true;
			_joyThreadLaunched = true;

			HRESULT hr;
			// Create a DirectInput device
			if (FAILED(hr = DirectInput8Create(GetModuleHandle(nullptr), DIRECTINPUT_VERSION,
				IID_IDirectInput8, (VOID**)&di, nullptr)))
			{
				printf("Failed initializing DirectInput library.\n");
				_joyThreadEnded = true;
				_inJoyThread = false;
				return(0);
			}

			// Look for the first simple joystick we can find.
			if (FAILED(hr = di->EnumDevices(DI8DEVCLASS_GAMECTRL, enumCallback,
				nullptr, DIEDFL_ATTACHEDONLY)))
			{
				printf("Failed enumerating devices.\n");
				_joyThreadEnded = true;
				_inJoyThread = false;
				return(0);
			}

			// Make sure we got a joystick
			joystickCount = 0;
			for (int i = 0;i < 4;i++)
			{
				if (joysticks[i].handle != nullptr)
					joystickCount++;
			}
			if (joystickCount == 0)
			{ // joystick not found
				_joyThreadEnded = true;
				_inJoyThread = false;
				return(0);
			}

			// Set joystick properties:
			for (int i = 0;i < 4;i++)
			{
				Joystick& joy = joysticks[i];

				if (joy.handle != nullptr)
				{
					if (FAILED(hr = joy.handle->SetDataFormat(&c_dfDIJoystick2)))
						printf("Failed at 'SetDataFormat'.\n");

					// If no window handle is provided, it is not possible to acquire exclusive level.
					// Exclusive level is required to apply forces on joysticks.
					// http://stackoverflow.com/a/13939469/702828
					// https://msdn.microsoft.com/en-us/library/windows/desktop/ee416848(v=vs.85).aspx
					// https://www.microsoft.com/msj/0298/force.aspx
					DWORD cooperative_level = DISCL_NONEXCLUSIVE | DISCL_BACKGROUND;
					if (winHandle) {
						printf("Window handle was provided, force control is enabled.\n");
						cooperative_level = DISCL_EXCLUSIVE | DISCL_BACKGROUND;
					}
					else {
						printf("No window handle was provided, force control is disabled.\n");
					}
					if (FAILED(hr = joy.handle->SetCooperativeLevel(winHandle, cooperative_level)))
						printf("Failed at 'SetCooperativeLevel'.\n");

					joy.capabilities.dwSize = sizeof(DIDEVCAPS);
					if (FAILED(hr = joy.handle->GetCapabilities(&joy.capabilities)))
						printf("Failed at 'GetCapabilities'.\n");

					// Since we will be playing force feedback effects, we should disable the
					// auto-centering spring.
					DIPROPDWORD dipdw;
					dipdw.diph.dwSize = sizeof(DIPROPDWORD);
					dipdw.diph.dwHeaderSize = sizeof(DIPROPHEADER);
					dipdw.diph.dwObj = 0;
					dipdw.diph.dwHow = DIPH_DEVICE;
					dipdw.dwData = DIPROPAUTOCENTER_OFF;

					if (FAILED(joy.handle->SetProperty(DIPROP_AUTOCENTER, &dipdw.diph))) {
						printf("Failed at 'SetProperty(DIPROP_AUTOCENTER, &dipdw.diph)'.\n");
						// Must not be acquired.
						// https://gathering.tweakers.net/forum/list_messages/1719669
						return false;
					}

					currentDeviceIndex = i;
					if (FAILED(hr = joy.handle->EnumObjects(enumAxesCallback, nullptr, DIDFT_AXIS)))
						printf("Failed at 'EnumObjects'.\n");

					// This simple sample only supports one or two axis joysticks
					if (joy.num_force_axes > 2)
						joy.num_force_axes = 2;

					// This application needs only one effect: Applying raw forces.
					DWORD rgdwAxes[2] = { DIJOFS_X, DIJOFS_Y };
					LONG rglDirection[2] = { 0, 0 };
					DICONSTANTFORCE cf = { 0 };

					DIEFFECT eff;
					ZeroMemory(&eff, sizeof(eff));
					eff.dwSize = sizeof(DIEFFECT);
					eff.dwFlags = DIEFF_CARTESIAN | DIEFF_OBJECTOFFSETS;
					eff.dwDuration = INFINITE;
					eff.dwSamplePeriod = 0;
					eff.dwGain = DI_FFNOMINALMAX;
					eff.dwTriggerButton = DIEB_NOTRIGGER;
					eff.dwTriggerRepeatInterval = 0;
					eff.cAxes = joy.num_force_axes;
					eff.rgdwAxes = rgdwAxes;
					eff.rglDirection = rglDirection;
					eff.lpEnvelope = 0;
					eff.cbTypeSpecificParams = sizeof(DICONSTANTFORCE);
					eff.lpvTypeSpecificParams = &cf;
					eff.dwStartDelay = 0;

					// Create the prepared effect
					if (FAILED(joy.handle->CreateEffect(GUID_ConstantForce,
						&eff, &joy.force_effect, nullptr)))
					{
						printf("Failed at 'CreateEffect'.\n");
					}

					if (!joy.force_effect) {
						printf("Invalid force_effect'.\n");
					}

					if (FAILED(joy.handle->Acquire()))
					{
						printf("Failed at 'Acquire'.\n");
					}
					if (joy.force_effect) {
						INT hr = DI_OK;
						if (FAILED(hr = joy.force_effect->Start(1, 0))) {
							std::string str = HRESULTToString(hr);
							printf("Failed at 'force_effect->Start'. Result = %s.\n", str.c_str());
							// Keep getting "80040205", DIERR_NOTEXCLUSIVEACQUIRED & VFW_E_FILTER_ACTIVE. Why?
							// https://msdn.microsoft.com/en-us/library/windows/desktop/microsoft.directx_sdk.idirectinputdevice8.idirectinputdevice8.setcooperativelevel(v=vs.85).aspx
							// https://msdn.microsoft.com/en-us/library/windows/desktop/microsoft.directx_sdk.idirectinputeffect.idirectinputeffect.start(v=vs.85).aspx
							// http://forum.devmaster.net/t/unknown-hresult-0x8006fc24-from-directinput/23425
							// https://github.com/freezedev/survival-guide-for-pirates/blob/master/lib/Dependencies/DirectX/DirectInput.pas
							// http://forums.ni.com/t5/LabVIEW/control-de-retroalimentacion-de-fuerza-volante-de-juegos/td-p/577046?db=5
						}
					}
				}
			}
			joyGoodToRead = true;

			while (_joyThreadLaunched)
			{
				for (int i = 0;i < 4;i++)
				{
					if (joysticks[i].handle != nullptr)
					{
						hr = joysticks[i].handle->Poll();
						bool cont = true;
						if (FAILED(hr))
						{
							hr = joysticks[i].handle->Acquire();
							while (hr == DIERR_INPUTLOST)
								hr = joysticks[i].handle->Acquire();

							if ((hr == DIERR_INVALIDPARAM) || (hr == DIERR_NOTINITIALIZED))
							{
								printf("Fatal error\n");
								cont = false;
							}

							if (cont)
							{
								if (hr == DIERR_OTHERAPPHASPRIO)
									cont = false;
							}
						}
						if (cont)
						{
							if (FAILED(hr = joysticks[i].handle->GetDeviceState(sizeof(DIJOYSTATE2), &joysticks[i].state)))
								printf("Failed at 'GetDeviceState'\n");

							setJoyForces(joysticks[i]);
						}
					}
				}
				Sleep(2);
			}

			for (int i = 0;i < 4;i++)
			{
				if (joysticks[i].handle) {
					joysticks[i].handle->Unacquire();
					joysticks[i].handle = nullptr;
				}

				if (joysticks[i].force_effect) { 
					joysticks[i].force_effect->Release(); 
					joysticks[i].force_effect = nullptr;
				}
			}

			_joyThreadEnded = true;
			_joyThreadLaunched = true;
			_inJoyThread = false;
			return(0);
		}

		void launchThreadIfNeeded()
		{
			if (!_inJoyThread)
			{
				_joyThreadEnded = false;
				_joyThreadLaunched = false;
				joyGoodToRead = false;
				CreateThread(nullptr, 0, _joyThread, nullptr, THREAD_PRIORITY_NORMAL, nullptr);
				while (!_joyThreadLaunched)
					Sleep(2);
				while (_inJoyThread && (!joyGoodToRead))
					Sleep(2);
			}
		}


		void killThreadIfNeeded()
		{
			if (_inJoyThread)
			{
				_joyThreadLaunched = false;
				while (!_joyThreadLaunched)
					Sleep(2);
				_joyThreadLaunched = false;
				_joyThreadEnded = false;
			}
		}


	} // private namespace

	void manageState() {
		//
		//TODO: If this DLL is dynamically linked against the MFC DLLs,
		//      any functions exported from this DLL which call into
		//      MFC must have the AFX_MANAGE_STATE macro added at the
		//      very beginning of the function.
		//
		//      For example:
		//
		//      extern "C" BOOL PASCAL EXPORT ExportedFunction()
		//      {
		//          AFX_MANAGE_STATE(AfxGetStaticModuleState());
		//          // normal function body here
		//      }
		//
		//      It is very important that this macro appear in each
		//      function, prior to any calls into MFC.  This means that
		//      it must appear as the first statement within the 
		//      function, even before any object variable declarations
		//      as their constructors may generate calls into the MFC
		//      DLL.
		//
		//      Please see MFC Technical Notes 33 and 58 for additional
		//      details.
		//

		AFX_MANAGE_STATE(AfxGetStaticModuleState());
	}

	DLLEXPORT void setWindowHandle(HWND handle) {
		manageState();
		printf("Setting window handle.\n");
		winHandle = handle;
	}

	DLLEXPORT void start()
	{
		manageState();
		launchThreadIfNeeded();
	}

	DLLEXPORT void stop() {
		manageState();
		killThreadIfNeeded();
	}


	DLLEXPORT int getJoyCount() {
		manageState();
		launchThreadIfNeeded();

		return joystickCount;
	}

	DLLEXPORT bool getJoyState(int joyId, Joystick& device) {
		manageState();
		launchThreadIfNeeded();

		if (joyId > joystickCount)
			return false;

		device = joysticks[joyId];

		return true;
	}

	DLLEXPORT bool printJoyState(int joyId) {
		manageState();
		launchThreadIfNeeded();

		if (joyId > joystickCount)
			return false;

		const Joystick& joy = joysticks[joyId];
		std::ostringstream ss;

		if (joy.handle == nullptr) {
			ss << "Invalid joystick instance." << std::endl;
		}
		else {
			ss << "Joystick " << joy.id << std::endl;
			ss << "nffaxes =  " << joy.num_force_axes << std::endl;
			ss << "axis1 = " << joy.state.lX << std::endl;
			ss << "axis2 = " << joy.state.lY << std::endl;
			ss << "axis3 = " << joy.state.lZ << std::endl;
			for (int i = 0;i < 16;i++)
			{
				ss << "button " << i << " = " << (joy.state.rgbButtons[i] != 0 ? true : false) << std::endl;
			}
			ss << "rotAxis1 = " << joy.state.lRx << std::endl;
			ss << "rotAxis2 = " << joy.state.lRy << std::endl;
			ss << "rotAxis3 = " << joy.state.lRz << std::endl;
			ss << "slider1 = " << joy.state.rglSlider[0] << std::endl;
			ss << "slider2 = " << joy.state.rglSlider[1] << std::endl;
			for (int i = 0;i < 4;i++)
			{
				ss << "pov " << i << " = " << joy.state.rgdwPOV[i] << std::endl;
			}
		}

		std::cout << ss.str();

		return true;
	}

	DLLEXPORT bool setJoyForces(int joyId, const std::array<float, 2>& forces) {
		if (joyId > joystickCount)
			return false;

		Joystick& joy = joysticks[joyId];
		joy.forces = forces;

		return true;
	}

	DLLEXPORT bool enableJoyForceControl(int joyId) {
		if (joyId > joystickCount)
			return false;

		return true;
	}

	DLLEXPORT bool disableJoyForceControl(int joyId) {
		if (joyId > joystickCount)
			return false;

		return true;
	}

}

LIBRARY vrepLib;

// --------------------------------------------------------------------------------------
// simExtJoySetForces
// --------------------------------------------------------------------------------------
#define LUA_SETFORCE "simExtJoySetForces"
// --------------------------------------------------------------------------------------

// --------------------------------------------------------------------------------------
// simExtJoyDisableForceControl
// --------------------------------------------------------------------------------------
#define LUA_DISABLEFORCE "simExtJoyDisableForceControl"

// --------------------------------------------------------------------------------------

// --------------------------------------------------------------------------------------
// simExtJoyGetCount
// --------------------------------------------------------------------------------------
#define LUA_GETCOUNT "simExtJoyGetCount"

void LUA_GETCOUNT_CALLBACK(SLuaCallBack* p){
	int joy_count = v_repExtJoystick::getJoyCount();

    // Prepare the return value:
    p->outputArgCount=1; // 1 return value
    p->outputArgTypeAndSize=(simInt*)simCreateBuffer(p->outputArgCount*2*sizeof(simInt)); // x return values takes x*2 simInt for the type and size buffer
    p->outputArgTypeAndSize[2*0+0]=sim_lua_arg_int; // The return value is an int
    p->outputArgTypeAndSize[2*0+1]=1;                   // Not used (table size if the return value was a table)
    p->outputInt=(simInt*)simCreateBuffer(1*sizeof(int)); // 1 int return value
    p->outputInt[0]= joy_count; // This is the integer value we want to return
}

void REGISTER_LUA_GETCOUNT() {
	int inArgs1[] = { 0 };
	simRegisterCustomLuaFunction(LUA_GETCOUNT, "number count=" LUA_GETCOUNT "()", inArgs1, LUA_GETCOUNT_CALLBACK);
}
// --------------------------------------------------------------------------------------

// --------------------------------------------------------------------------------------
// simExtJoyGetCount
// --------------------------------------------------------------------------------------
#define LUA_GETDATA "simExtJoyGetData"

void LUA_GETDATA_CALLBACK(SLuaCallBack* p)
{
    v_repExtJoystick::manageState();
	v_repExtJoystick::launchThreadIfNeeded();

    bool error=true;
    int index=0;
    if (p->inputArgCount>0)
    { // Ok, we have at least 1 input argument
        if (p->inputArgTypeAndSize[0*2+0]==sim_lua_arg_int)
        { // Ok, we have an int as argument 1
            if ( (p->inputInt[0]<v_repExtJoystick::joystickCount)&&(p->inputInt[0]>=0) )
            { // Ok, there is a device at this index!
                index=p->inputInt[0];
                error=false;
            }
            else
                simSetLastError(LUA_GETDATA,"Invalid index."); // output an error
        }
        else
            simSetLastError(LUA_GETDATA,"Wrong argument type/size."); // output an error
    }
    else
        simSetLastError(LUA_GETDATA,"Not enough arguments."); // output an error

    // Now we prepare the return value(s):
    if (error)
    {
        p->outputArgCount=0; // 0 return values --> nil (error)
    }
    else
    {
        p->outputArgCount=5; // 5 return value
        p->outputArgTypeAndSize=(simInt*)simCreateBuffer(p->outputArgCount*10*sizeof(simInt)); // x return values takes x*2 simInt for the type and size buffer
        p->outputArgTypeAndSize[2*0+0]=sim_lua_arg_int|sim_lua_arg_table;   // The return value is an int table
        p->outputArgTypeAndSize[2*0+1]=3;                   // table size is 3 (the 3 axes)
        p->outputArgTypeAndSize[2*1+0]=sim_lua_arg_int; // The return value is an int
        p->outputArgTypeAndSize[2*1+1]=1;                   // Not used (not a table)
        p->outputArgTypeAndSize[2*2+0]=sim_lua_arg_int|sim_lua_arg_table;   // The return value is an int table
        p->outputArgTypeAndSize[2*2+1]=3;                   // table size is 3 (the 3 rot axes)
        p->outputArgTypeAndSize[2*3+0]=sim_lua_arg_int|sim_lua_arg_table;   // The return value is an int table
        p->outputArgTypeAndSize[2*3+1]=2;                   // table size is 2 (the 2 sliders)
        p->outputArgTypeAndSize[2*4+0]=sim_lua_arg_int|sim_lua_arg_table;   // The return value is an int table
        p->outputArgTypeAndSize[2*4+1]=4;                   // table size is 4 (the 4 pov values)
        p->outputInt=(simInt*)simCreateBuffer(13*sizeof(int)); // 13 int return value (3 for the axes + 1 for the buttons + 3 for rot axis, +2 for slider, +4 for pov)

		v_repExtJoystick::Joystick joy;
		v_repExtJoystick::getJoyState(index, joy);

        p->outputInt[0]= joy.state.lX; // axis 1
        p->outputInt[1]= joy.state.lY; // axis 2
        p->outputInt[2]= joy.state.lZ; // axis 3
        
        // now the buttons:
        p->outputInt[3]=0;
        for (int i=0;i<16;i++)
        {
            if (joy.state.rgbButtons[i]!=0)
                p->outputInt[3]|=(1<<i);
        }

        p->outputInt[4]= joy.state.lRx; // rot axis 1
        p->outputInt[5]= joy.state.lRy; // rot axis 2
        p->outputInt[6]= joy.state.lRz; // rot axis 3

        p->outputInt[7]= joy.state.rglSlider[0]; // slider 1
        p->outputInt[8]= joy.state.rglSlider[1]; // slider 2

        p->outputInt[9]= joy.state.rgdwPOV[0]; // POV value 1
        p->outputInt[10]= joy.state.rgdwPOV[1]; // POV value 1
        p->outputInt[11]= joy.state.rgdwPOV[2]; // POV value 1
        p->outputInt[12]= joy.state.rgdwPOV[3]; // POV value 1

    }
}

void REGISTER_LUA_GETDATA(){
	int inArgs2[] = { 1,sim_lua_arg_int };
	simRegisterCustomLuaFunction(LUA_GETDATA, "table_3 axes, number buttons,table_3 rotAxes,table_2 slider,table_4 pov=" LUA_GETDATA "(number deviceIndex)", inArgs2, LUA_GETDATA_CALLBACK);
}
// --------------------------------------------------------------------------------------


VREP_DLLEXPORT unsigned char v_repStart(void* reservedPointer,int reservedInt)
{ // This is called just once, at the start of V-REP
	v_repExtJoystick::manageState();

    // Dynamically load and bind V-REP functions:
    char curDirAndFile[1024];
    GetModuleFileName(nullptr,curDirAndFile,1023);
    PathRemoveFileSpec(curDirAndFile);
    std::string currentDirAndPath(curDirAndFile);
    std::string temp(currentDirAndPath);
    temp+="\\v_rep.dll";
    vrepLib=loadVrepLibrary(temp.c_str());
    if (vrepLib==nullptr)
    {
        std::cout << "Error, could not find or correctly load v_rep.dll. Cannot start 'Joystick' plugin.\n";
        return(0); // Means error, V-REP will unload this plugin
    }
    if (getVrepProcAddresses(vrepLib)==0)
    {
        std::cout << "Error, could not find all required functions in v_rep.dll. Cannot start 'Joystick' plugin.\n";
        unloadVrepLibrary(vrepLib);
        return(0); // Means error, V-REP will unload this plugin
    }

    int vrepVer;
    simGetIntegerParameter(sim_intparam_program_version,&vrepVer);
    if (vrepVer<20600) // if V-REP version is smaller than 2.06.00
    {
        std::cout << "Sorry, your V-REP copy is somewhat old, V-REP 2.6.0 or later is required. Cannot start 'Joystick' plugin.\n";
        unloadVrepLibrary(vrepLib);
        return(0); // initialization failed!!
    }

    // Register 2 new Lua commands:
	REGISTER_LUA_GETCOUNT();
	REGISTER_LUA_GETDATA();

	// Tries to enable force control
	std::string console_path(currentDirAndPath);
	console_path += "\\vrep.exe";
	HWND handle = nullptr;
	handle = FindWindowA(NULL, console_path.c_str());
	if (handle) {
		std::cout << "v_repExtJoystick: Acquired VREP console handle.\n";
		v_repExtJoystick::setWindowHandle(handle);
	}

	std::cout << "v_repExtJoystick: version 2017-04-22, Arthur Queiroz.\n";

    return(3);  // initialization went fine, return the version number of this plugin!
                // version 2 was for V-REP 2.5.12 or earlier
}

VREP_DLLEXPORT void v_repEnd()
{ // This is called just once, at the end of V-REP
	v_repExtJoystick::manageState();
    // Release resources here..
    v_repExtJoystick::stop();
    unloadVrepLibrary(vrepLib); // release the library
}

VREP_DLLEXPORT void* v_repMessage(int message,int* auxiliaryData,void* customData,int* replyData)
{ // This is called quite often. Just watch out for messages/events you want to handle
	v_repExtJoystick::manageState();

    // This function should not generate any error messages:
    int errorModeSaved;
    simGetIntegerParameter(sim_intparam_error_report_mode,&errorModeSaved);
    simSetIntegerParameter(sim_intparam_error_report_mode,sim_api_errormessage_ignore);

    void* retVal=nullptr;

    if (message==sim_message_eventcallback_instancepass)
    { // It is important to always correctly react to events in V-REP. This message is the most convenient way to do so:

        int flags=auxiliaryData[0];
        bool sceneContentChanged=((flags&(1+2+4+8+16+32+64+256))!=0); // object erased, created, model or scene loaded, und/redo called, instance switched, or object scaled since last sim_message_eventcallback_instancepass message 
        bool instanceSwitched=((flags&64)!=0);

        if (instanceSwitched)
        {

        }

        if (sceneContentChanged)
        { // we actualize plugin objects for changes in the scene

        }
    }

    // You can add more messages to handle here

    simSetIntegerParameter(sim_intparam_error_report_mode,errorModeSaved); // restore previous settings
    return(retVal);
}
