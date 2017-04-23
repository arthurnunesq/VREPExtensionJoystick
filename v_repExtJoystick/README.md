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

*) Unresolved symbols in projects that reference another unamanaged library.

	Severity	Code	Description	Project	File	Line	Suppression State
	Error	LNK2019	unresolved external symbol "void __cdecl killThreadIfNeeded(void)" (?killThreadIfNeeded@@YAXXZ) referenced in function "int __cdecl run(void)" (?run@@YAHXZ)	v_repExtJoystickConsole	E:\OneDrive\Projetos\VREPExtensionJoystick\v_repExtJoystickConsole\v_repExtJoystickConsole.obj	1	

Possible causes:
1) Methods of a DLL must be explicitly exported so they can be visible to other applications:
https://msdn.microsoft.com/en-us/library/799kze2z.aspx
https://msdn.microsoft.com/en-us/library/wdsk6as6.aspx
https://msdn.microsoft.com/en-us/library/30e78zd0.aspx
https://msdn.microsoft.com/en-us/library/z4zxe9k8.aspx

2) Referencing unmanaged C++ projects seem to be broken:
https://connect.microsoft.com/VisualStudio/feedback/details/766064/visual-studio-2012-copy-local-cannot-be-set-via-the-property-pages
http://stackoverflow.com/questions/4922883/unmanaged-c-dll-dependency-not-getting-copied-to-application-folder-but-differ
http://stackoverflow.com/questions/13590014/visual-studio-copy-local-on-reference-doesnt-work
http://stackoverflow.com/questions/36374685/dumpbin-is-not-recognized-dumpbin-exe-is-missing

