// v_repExtJoystickConsole.cpp : Defines the entry point for the console application.
//

#include "stdafx.h"
#include "v_repExtJoystickConsole.h"
#include "v_repExtJoystick.h"
#include <iostream>

#ifdef _DEBUG
#define new DEBUG_NEW
#endif


// The one and only application object

CWinApp theApp;

using namespace std;

int run() {
	std::cout << "v_repExtJoystick" << std::endl;
	std::cout << "Joystick count: " << simExtJoyGetCount() << std::endl;

	killThreadIfNeeded();

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
			nRetCode = run();
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
