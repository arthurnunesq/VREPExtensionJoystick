// v_repExtJoystickConsole.cpp : Defines the entry point for the console application.
//

#include "stdafx.h"
#include "v_repExtJoystickConsole.h"
#include "v_repExtJoystick.h"
#include <iostream>
#include <windows.h> 

#ifdef _DEBUG
#define new DEBUG_NEW
#endif


// The one and only application object

CWinApp theApp;
bool exit_flag = false;

using namespace std;

BOOL WINAPI consoleHandler(DWORD signal) {
	if (signal == CTRL_C_EVENT) {
		printf("Ctrl-C handled\n"); // do cleanup
		exit_flag = true;
	}

	return TRUE;
}

int run() {
	std::cout << "v_repExtJoystick" << std::endl;
	std::cout << "Joystick count: " << v_repExtJoystick::getJoyCount() << std::endl;

	while (!exit_flag) {
		system("cls"); // Avoids flickering
		v_repExtJoystick::printJoyState(0);

		Sleep(100);
	}

	v_repExtJoystick::start();

	std::system("pause");
	return 0;
}

int main()
{
    int nRetCode = 0;

    HMODULE hModule = ::GetModuleHandle(nullptr);

    if (hModule != nullptr)
    {
        // initialize MFC and print and error on failure
        if (!AfxWinInit(hModule, nullptr, ::GetCommandLine(), 0))
        {
            // TODO: change error code to suit your needs
            wprintf(L"Fatal Error: MFC initialization failed\n");
            nRetCode = 1;
        }
        else
        {
			if (!SetConsoleCtrlHandler(consoleHandler, TRUE)) {
				printf("\nERROR: Could not set control handler");
				nRetCode =  1;
			}
			else {
				nRetCode = run();
			}
		}
    }
    else
    {
        // TODO: change error code to suit your needs
        wprintf(L"Fatal Error: GetModuleHandle failed\n");
        nRetCode = 1;
    }

    return nRetCode;
}
