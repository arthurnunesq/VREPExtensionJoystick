#pragma once

#ifndef __AFXWIN_H__
    #error "include 'stdafx.h' before including this file for PCH"
#endif
#include <dinput.h>
#include <array>
#include <string>

#define VREP_DLLEXPORT extern "C" __declspec(dllexport)
#define DLLEXPORT __declspec(dllexport)

class DLLEXPORT Joystick {
	public:
		int id = 0;
		LPDIRECTINPUTDEVICE8 handle = NULL;
		DIDEVCAPS capabilities;
		DIJOYSTATE2 state;
		int num_force_feedback_axes = 0;

		void print(); // For debug purposes
};

DLLEXPORT void launchThreadIfNeeded();
DLLEXPORT void killThreadIfNeeded();

DLLEXPORT int simExtJoyGetCount();
DLLEXPORT bool simExtJoyGetDevice(int joyId, Joystick& device);
DLLEXPORT bool simExtJoyGetData(int joyId, DIJOYSTATE2& state);
DLLEXPORT bool simExtJoySetForces(const std::array<int, 2>& forces);

// The 3 required entry points of the plugin:
VREP_DLLEXPORT unsigned char v_repStart(void* reservedPointer,int reservedInt);
VREP_DLLEXPORT void v_repEnd();
VREP_DLLEXPORT void* v_repMessage(int message,int* auxiliaryData,void* customData,int* replyData);