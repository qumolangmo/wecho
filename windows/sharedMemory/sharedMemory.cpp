#include <windows.h>
#include <AclAPI.h>
#include <iostream>
#include <sddl.h>
#include "../../native/enum.h"

int main() {
    SECURITY_ATTRIBUTES sa = { 0 };
    SECURITY_ATTRIBUTES sd = { 0 };
    PACL dacl = nullptr;
    PSID everyone_sid = nullptr;
    PSID system_sid = nullptr;
    PSID service_sid = nullptr;
    EXPLICIT_ACCESS ea[3] = {0};
    SID_IDENTIFIER_AUTHORITY world_auth = SECURITY_WORLD_SID_AUTHORITY;
    SID_IDENTIFIER_AUTHORITY nt_auth = SECURITY_NT_AUTHORITY;

    if (!InitializeSecurityDescriptor(&sd, SECURITY_DESCRIPTOR_REVISION)) {
        std::cout << "InitializeSecurityDescriptor failed, error = " << GetLastError() << "\n";
        return 1;
    }

    if (!AllocateAndInitializeSid(&world_auth, 1,
        SECURITY_WORLD_RID,
        0, 0, 0, 0, 0, 0, 0,
        &everyone_sid)) {

        std::cout << "AllocateAndInitializeSid failed, error = " << GetLastError() << "\n";
        return 1;
    }

    if (!AllocateAndInitializeSid(&nt_auth, 1,
        SECURITY_LOCAL_SYSTEM_RID,
        0, 0, 0, 0, 0, 0, 0,
        &system_sid)) {

        FreeSid(everyone_sid);
        std::cout << "AllocateAndInitializeSid(nt auth) failed, error = " << GetLastError() << "\n";
        return 1;
    }

    if (!AllocateAndInitializeSid(&world_auth, 1,
        SECURITY_SERVICE_RID,
        0, 0, 0, 0, 0, 0, 0,
        &service_sid)) {

        FreeSid(everyone_sid);
        FreeSid(system_sid);
        std::cout << "AllocateAndInitializeSid(world auth) failed, error = " << GetLastError() << "\n";
        return 1;
    }

    ea[0].grfAccessPermissions = FILE_MAP_ALL_ACCESS | EVENT_ALL_ACCESS;
    ea[0].grfAccessMode = SET_ACCESS;
    ea[0].grfInheritance = NO_INHERITANCE;
    ea[0].Trustee.TrusteeForm = TRUSTEE_IS_SID;
    ea[0].Trustee.TrusteeType = TRUSTEE_IS_WELL_KNOWN_GROUP;
    ea[0].Trustee.ptstrName = (LPTSTR)everyone_sid;

    ea[1].grfAccessPermissions = FILE_MAP_ALL_ACCESS | EVENT_ALL_ACCESS;
    ea[1].grfAccessMode = SET_ACCESS;
    ea[1].grfInheritance = NO_INHERITANCE;
    ea[1].Trustee.TrusteeForm = TRUSTEE_IS_SID;
    ea[1].Trustee.TrusteeType = TRUSTEE_IS_WELL_KNOWN_GROUP;
    ea[1].Trustee.ptstrName = (LPTSTR)system_sid;

    ea[2].grfAccessPermissions = FILE_MAP_ALL_ACCESS | EVENT_ALL_ACCESS;
    ea[2].grfAccessMode = SET_ACCESS;
    ea[2].grfInheritance = NO_INHERITANCE;
    ea[2].Trustee.TrusteeForm = TRUSTEE_IS_SID;
    ea[2].Trustee.TrusteeType = TRUSTEE_IS_WELL_KNOWN_GROUP;
    ea[2].Trustee.ptstrName = (LPTSTR)service_sid;

    if (SetEntriesInAcl(3, ea, nullptr, &dacl) != ERROR_SUCCESS) {
        std::cout << "SetEntriesInAcl failed, error = " << GetLastError() << "\n";
        FreeSid(everyone_sid);
        FreeSid(system_sid);
        FreeSid(service_sid);

        return 1;
    }

    sa.nLength = sizeof(SECURITY_ATTRIBUTES);
    sa.lpSecurityDescriptor = &sd;
    sa.bInheritHandle = FALSE;

    const wchar_t* mem_name = L"Global\\WechoAPO_SharedData";

    HANDLE map_file = CreateFileMappingW(
        INVALID_HANDLE_VALUE,
        &sa,
        PAGE_READWRITE | SEC_COMMIT,
        0,
        2 * 1024 * 1024,
        mem_name);

    if (!map_file) {
        std::cout << "CreateFileMappingW failed, error = " << GetLastError() << "\n";
        LocalFree(dacl);
        FreeSid(everyone_sid);
        FreeSid(system_sid);
        FreeSid(service_sid);

        return 1;
    }

    HANDLE never_exit = CreateEvent(nullptr, TRUE, FALSE, nullptr);

    if (!never_exit) {
        std::cout << "CreateEvent failed, error = " << GetLastError() << "\n";
        CloseHandle(map_file);
        LocalFree(dacl);
        FreeSid(everyone_sid);
        FreeSid(system_sid);
        FreeSid(service_sid);
    }

    while (true) {
        WaitForSingleObject(never_exit, INFINITE);
    }
    
    CloseHandle(never_exit);
    CloseHandle(map_file);
    LocalFree(dacl);
    FreeSid(everyone_sid);
    FreeSid(system_sid);
    FreeSid(service_sid);

    return 0;
}