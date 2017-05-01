#pragma once

#ifndef __AFXWIN_H__
    #error "include 'stdafx.h' before including this file for PCH"
#endif
#include <dinput.h>
#include <array>
#include <string>

#define VREP_DLLEXPORT extern "C" __declspec(dllexport)
#define DLLEXPORT __declspec(dllexport)

namespace v_repExtJoystick {
	class DLLEXPORT Joystick {
	public:
		int id = 0;
		LPDIRECTINPUTDEVICE8 handle = NULL;
		DIDEVCAPS capabilities;
		DIJOYSTATE2 state;
		int num_force_axes = 0;
		std::array<float, 2> forces = { 0, 0 };
		LPDIRECTINPUTEFFECT force_effect = nullptr;
		bool force_feedback_enabled = false;

	};

	DLLEXPORT void start();
	DLLEXPORT void stop();

	DLLEXPORT int getJoyCount();
	DLLEXPORT bool getJoyState(int joyId, Joystick& device);
	DLLEXPORT bool printJoyState(int joyId);
	DLLEXPORT bool setJoyForces(int joyId, const std::array<float, 2>& forces);
	DLLEXPORT bool enableJoyForceControl(int joyId);
	DLLEXPORT bool disableJoyForceControl(int joyId);
}

// The 3 required entry points of the plugin:
VREP_DLLEXPORT unsigned char v_repStart(void* reservedPointer,int reservedInt);
VREP_DLLEXPORT void v_repEnd();
VREP_DLLEXPORT void* v_repMessage(int message,int* auxiliaryData,void* customData,int* replyData);