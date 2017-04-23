*) Directory structure must be preserved so vrep libraries compile correctly:
	.
	common
		v_repLib.cpp
	include
		v_repLib.h
	windowsOnlyProjects
		v_repExtJoystick
			v_repExtJoystick.cpp

*) Fix for error:
	nafxcwd.lib _DllMain@12 already defined in LIBCMTD.lib(dll_dllmain_stub.obj)

http://stackoverflow.com/a/1741416/702828
https://support.microsoft.com/en-us/help/148652/a-lnk2005-error-occurs-when-the-crt-library-and-mfc-libraries-are-linked-in-the-wrong-order-in-visual-c

*) Fix warning
	Severity	Code	Description	Project	File	Line	Suppression State
	Warning	LNK4075	ignoring '/EDITANDCONTINUE' due to '/SAFESEH' specification	v_repExtJoystick	E:\OneDrive\Projetos\VREPExtensionJoystick\v_repExtJoystick\windowsOnlyProjects\v_repExtJoystick\v_repLib.obj	1	

http://stackoverflow.com/a/24214861/702828
