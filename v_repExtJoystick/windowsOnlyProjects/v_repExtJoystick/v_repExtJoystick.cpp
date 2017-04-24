// V-REP plugin "Joystick" by Eric Rohmer, December 2011

#include "stdafx.h"
#include "v_repExtJoystick.h"
#include "v_repLib.h"
#include <iostream>
#include <sstream>
#include <shlwapi.h> // for the "PathRemoveFileSpec" function


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

#define LUA_GETCOUNT "simExtJoyGetCount"
#define LUA_GETDATA "simExtJoyGetData"


void Joystick::print() {
	std::ostringstream ss;

	if (handle == NULL) {
		ss << "Invalid joystick instance." << std::endl;
	}
	else {
		ss << "Joystick " << id << std::endl;
		ss << "nffaxes =  " << num_force_feedback_axes << std::endl;
		ss << "axis1 = " << state.lX << std::endl;
		ss << "axis2 = " << state.lY << std::endl;
		ss << "axis3 = " << state.lZ << std::endl;
		for (int i = 0;i<16;i++)
		{
			ss << "button " << i << " = " << (state.rgbButtons[i] != 0 ? true : false) << std::endl;
		}
		ss << "rotAxis1 = " << state.lRx << std::endl;
		ss << "rotAxis2 = " << state.lRy << std::endl;
		ss << "rotAxis3 = " << state.lRz << std::endl;
		ss << "slider1 = " << state.rglSlider[0] << std::endl;
		ss << "slider2 = " << state.rglSlider[1] << std::endl;
		for (int i = 0;i<4;i++)
		{
			ss << "pov " << i << " = " << state.rgdwPOV[i] << std::endl;
		}
	}

	std::cout << ss.str();
}

volatile bool _joyThreadLaunched=false;
volatile bool _joyThreadEnded=false;
volatile bool _inJoyThread=false;
volatile bool joyGoodToRead=false;
LPDIRECTINPUT8 di;

Joystick joysticks[4];
int currentDeviceIndex=0;
int joystickCount=0;

LIBRARY vrepLib;

BOOL CALLBACK enumCallback(const DIDEVICEINSTANCE* instance, VOID* context)
{
    HRESULT hr;
    hr = di->CreateDevice(instance->guidInstance, &joysticks[currentDeviceIndex].handle, NULL);
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
    propRange.diph.dwSize       = sizeof(DIPROPRANGE); 
    propRange.diph.dwHeaderSize = sizeof(DIPROPHEADER); 
    propRange.diph.dwHow        = DIPH_BYID; 
    propRange.diph.dwObj        = instance->dwType;
    propRange.lMin              = -1000; 
    propRange.lMax              = +1000; 
    
    // Set the range for the axis
    if (FAILED(joysticks[currentDeviceIndex].handle->SetProperty(DIPROP_RANGE, &propRange.diph))) {
        return DIENUM_STOP;
    }

	// Counts num of forcefeedback enables axes
	auto pdwNumForceFeedbackAxis = reinterpret_cast<DWORD*>(context);
	if ((instance->dwFlags & DIDOI_FFACTUATOR) != 0)
		joysticks[currentDeviceIndex].num_force_feedback_axes++;

    return DIENUM_CONTINUE;
}

DWORD WINAPI _joyThread(LPVOID lpParam)
{
    _inJoyThread=true;
    _joyThreadLaunched=true;

    HRESULT hr;
    // Create a DirectInput device
    if (FAILED(hr = DirectInput8Create(GetModuleHandle(NULL), DIRECTINPUT_VERSION, 
                                   IID_IDirectInput8, (VOID**)&di, NULL)))
    {
        printf("Failed initializing DirectInput library.\n");
        _joyThreadEnded=true;
        _inJoyThread=false;
        return(0);
    }

    // Look for the first simple joystick we can find.
    if (FAILED(hr = di->EnumDevices(DI8DEVCLASS_GAMECTRL, enumCallback,
                                NULL, DIEDFL_ATTACHEDONLY)))
    {
        printf("Failed enumerating devices.\n");
        _joyThreadEnded=true;
        _inJoyThread=false;
        return(0);
    }

    // Make sure we got a joystick
    joystickCount=0;
    for (int i=0;i<4;i++)
    {
        if (joysticks[i].handle!=NULL)
            joystickCount++;
    }
    if (joystickCount==0) 
    { // joystick not found
        _joyThreadEnded=true;
        _inJoyThread=false;
        return(0);
    }

    // Set joystick properties:
    for (int i=0;i<4;i++)
    {
        if (joysticks[i].handle!=NULL)
        {
            if (FAILED(hr = joysticks[i].handle->SetDataFormat(&c_dfDIJoystick2)))
                printf("Failed at 'SetDataFormat'.\n");

            if (FAILED(hr = joysticks[i].handle->SetCooperativeLevel(NULL, DISCL_EXCLUSIVE | DISCL_FOREGROUND)))
				(void)0;// do not output an error here!      printf("Failed at 'SetCooperativeLevel'.\n");
			// http://stackoverflow.com/a/13939469/702828

			joysticks[i].capabilities.dwSize = sizeof(DIDEVCAPS);
            if (FAILED(hr = joysticks[i].handle->GetCapabilities(&joysticks[i].capabilities)))
                printf("Failed at 'GetCapabilities'.\n");

            currentDeviceIndex=i;
            if (FAILED(hr = joysticks[i].handle->EnumObjects(enumAxesCallback, NULL, DIDFT_AXIS)))
                printf("Failed at 'EnumObjects'.\n");
        }
    }
    joyGoodToRead=true;

    while (_joyThreadLaunched)
    {
        for (int i=0;i<4;i++)
        {
            if (joysticks[i].handle!=NULL)
            {
                hr = joysticks[i].handle->Poll();
                bool cont=true;
                if (FAILED(hr)) 
                {
                    hr = joysticks[i].handle->Acquire();
                    while (hr == DIERR_INPUTLOST)
                        hr = joysticks[i].handle->Acquire();

                    if ((hr == DIERR_INVALIDPARAM) || (hr == DIERR_NOTINITIALIZED))
                    {
                        printf("Fatal error\n");
                        cont=false;
                    }

                    if (cont)
                    {
                        if (hr == DIERR_OTHERAPPHASPRIO)
                            cont=false;
                    }
                }
                if (cont)
                {
                    if (FAILED(hr = joysticks[i].handle->GetDeviceState(sizeof(DIJOYSTATE2), &joysticks[i].state)))
                        printf("Failed at 'GetDeviceState'\n");
                }
            }
        }
        Sleep(2);
    }

    for (int i=0;i<4;i++)
    {
        if (joysticks[i].handle!=NULL)
			joysticks[i].handle->Unacquire();
		joysticks[i].handle=NULL;
    }

    _joyThreadEnded=true;
    _joyThreadLaunched=true;
    _inJoyThread=false;
    return(0);
}

DLLEXPORT void launchThreadIfNeeded()
{
    if (!_inJoyThread)
    {
        _joyThreadEnded=false;
        _joyThreadLaunched=false;
        joyGoodToRead=false;
        CreateThread(NULL,0,_joyThread,NULL,THREAD_PRIORITY_NORMAL,NULL);
        while (!_joyThreadLaunched)
            Sleep(2);
        while (_inJoyThread&&(!joyGoodToRead))
            Sleep(2);
    }
}


DLLEXPORT void killThreadIfNeeded()
{
    if (_inJoyThread)
    {
        _joyThreadLaunched=false;
        while (!_joyThreadLaunched)
            Sleep(2);
        _joyThreadLaunched=false;
        _joyThreadEnded=false;
    }
}


DLLEXPORT int simExtJoyGetCount() {
	AFX_MANAGE_STATE(AfxGetStaticModuleState());
	launchThreadIfNeeded();

	return joystickCount;
}

DLLEXPORT bool simExtJoyGetDevice(int joyId, Joystick& device) {
	AFX_MANAGE_STATE(AfxGetStaticModuleState());
	launchThreadIfNeeded();

	if (joyId > joystickCount)
		return false;

	device = joysticks[joyId];

	return true;
}


DLLEXPORT bool simExtJoyGetData(int joyId, DIJOYSTATE2& state) {
	AFX_MANAGE_STATE(AfxGetStaticModuleState());
	launchThreadIfNeeded();

	if (joyId > joystickCount)
		return false;

	state = joysticks[joyId].state;

	return true;
}


DLLEXPORT bool simExtJoySetForces(const std::array<int, 2>& forces) {
	return true;
}

void LUA_GETCOUNT_CALLBACK(SLuaCallBack* p)
{
    AFX_MANAGE_STATE(AfxGetStaticModuleState());
    launchThreadIfNeeded();

    // Prepare the return value:
    p->outputArgCount=1; // 1 return value
    p->outputArgTypeAndSize=(simInt*)simCreateBuffer(p->outputArgCount*2*sizeof(simInt)); // x return values takes x*2 simInt for the type and size buffer
    p->outputArgTypeAndSize[2*0+0]=sim_lua_arg_int; // The return value is an int
    p->outputArgTypeAndSize[2*0+1]=1;                   // Not used (table size if the return value was a table)
    p->outputInt=(simInt*)simCreateBuffer(1*sizeof(int)); // 1 int return value
    p->outputInt[0]=joystickCount; // This is the integer value we want to return
}

void LUA_GETDATA_CALLBACK(SLuaCallBack* p)
{
    AFX_MANAGE_STATE(AfxGetStaticModuleState());
    launchThreadIfNeeded();

    bool error=true;
    int index=0;
    if (p->inputArgCount>0)
    { // Ok, we have at least 1 input argument
        if (p->inputArgTypeAndSize[0*2+0]==sim_lua_arg_int)
        { // Ok, we have an int as argument 1
            if ( (p->inputInt[0]<joystickCount)&&(p->inputInt[0]>=0) )
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
        p->outputInt[0]=joysticks[index].state.lX; // axis 1
        p->outputInt[1]=joysticks[index].state.lY; // axis 2
        p->outputInt[2]=joysticks[index].state.lZ; // axis 3
        
        // now the buttons:
        p->outputInt[3]=0;
        for (int i=0;i<16;i++)
        {
            if (joysticks[index].state.rgbButtons[i]!=0)
                p->outputInt[3]|=(1<<i);
        }

        p->outputInt[4]=joysticks[index].state.lRx; // rot axis 1
        p->outputInt[5]=joysticks[index].state.lRy; // rot axis 2
        p->outputInt[6]=joysticks[index].state.lRz; // rot axis 3

        p->outputInt[7]=joysticks[index].state.rglSlider[0]; // slider 1
        p->outputInt[8]=joysticks[index].state.rglSlider[1]; // slider 2

        p->outputInt[9]=joysticks[index].state.rgdwPOV[0]; // POV value 1
        p->outputInt[10]=joysticks[index].state.rgdwPOV[1]; // POV value 1
        p->outputInt[11]=joysticks[index].state.rgdwPOV[2]; // POV value 1
        p->outputInt[12]=joysticks[index].state.rgdwPOV[3]; // POV value 1

    }
}




VREP_DLLEXPORT unsigned char v_repStart(void* reservedPointer,int reservedInt)
{ // This is called just once, at the start of V-REP
    AFX_MANAGE_STATE(AfxGetStaticModuleState());

    // Dynamically load and bind V-REP functions:
    char curDirAndFile[1024];
    GetModuleFileName(NULL,curDirAndFile,1023);
    PathRemoveFileSpec(curDirAndFile);
    std::string currentDirAndPath(curDirAndFile);
    std::string temp(currentDirAndPath);
    temp+="\\v_rep.dll";
    vrepLib=loadVrepLibrary(temp.c_str());
    if (vrepLib==NULL)
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
    int inArgs1[]={0};
    simRegisterCustomLuaFunction(LUA_GETCOUNT, "number count=" LUA_GETCOUNT "()", inArgs1, LUA_GETCOUNT_CALLBACK);

    int inArgs2[]={1,sim_lua_arg_int};
    simRegisterCustomLuaFunction(LUA_GETDATA, "table_3 axes, number buttons,table_3 rotAxes,table_2 slider,table_4 pov=" LUA_GETDATA "(number deviceIndex)", inArgs2, LUA_GETDATA_CALLBACK);

	std::cout << "VREP Joystick plugin, 2017-04-22, Arthur Queiroz.\n";

    return(3);  // initialization went fine, return the version number of this plugin!
                // version 2 was for V-REP 2.5.12 or earlier
}

VREP_DLLEXPORT void v_repEnd()
{ // This is called just once, at the end of V-REP
    AFX_MANAGE_STATE(AfxGetStaticModuleState());
    // Release resources here..
    killThreadIfNeeded();
    unloadVrepLibrary(vrepLib); // release the library
}

VREP_DLLEXPORT void* v_repMessage(int message,int* auxiliaryData,void* customData,int* replyData)
{ // This is called quite often. Just watch out for messages/events you want to handle
    AFX_MANAGE_STATE(AfxGetStaticModuleState());
    // This function should not generate any error messages:
    int errorModeSaved;
    simGetIntegerParameter(sim_intparam_error_report_mode,&errorModeSaved);
    simSetIntegerParameter(sim_intparam_error_report_mode,sim_api_errormessage_ignore);

    void* retVal=NULL;

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
