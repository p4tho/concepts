use std::env;
use std::ffi::CString;
use std::mem;
use std::os::raw::c_void;
use std::path::PathBuf;
use windows::Win32::Foundation::CloseHandle;
use windows::core::s;
use windows::Win32::Foundation::HANDLE;
use windows::Win32::System::Diagnostics::Debug::*;
use windows::Win32::System::LibraryLoader::*;
use windows::Win32::System::Memory::*;
use windows::Win32::System::Threading::*;

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 3 {
        panic!("Usage: Injector <pid> <dll path>");
    }

    let pid: u32 = args[1].parse().unwrap();
    let dll_path = PathBuf::from(&args[2]);
    let abs_dll_path = dll_path.canonicalize().expect("Invalid DLL path.");
    let abs_dll_path_str = abs_dll_path.to_str().expect("Invalid UTF-8 in path");
    
    let c_dll_path = CString::new(abs_dll_path_str).expect("CString::new failed");
    let dll_path_size = c_dll_path.as_bytes_with_nul().len();

    unsafe {
        // Get handle to process to inject DLL
        let h_process: HANDLE = OpenProcess(
            PROCESS_VM_WRITE | PROCESS_VM_OPERATION | PROCESS_CREATE_THREAD,
            false,
            pid,
        )
        .expect("OpenProcess failed.");

        // Allocate memory for DLL file path
        let dll_file_path = VirtualAllocEx(
            h_process,
            None,
            dll_path_size,
            MEM_COMMIT | MEM_RESERVE,
            PAGE_READWRITE,
        );
        if dll_file_path.is_null() {
            panic!("VirtualAllocEx failed.");
        }

        // Load DLL into memory
        WriteProcessMemory(
            h_process,
            dll_file_path,
            c_dll_path.as_bytes_with_nul().as_ptr() as *const c_void,
            dll_path_size,
            None,
        )
        .expect("WriteProcessMemory failed.");

        // Find LoadLibraryA function in kernel32.dll
        let h_module = GetModuleHandleA(s!("kernel32.dll")).unwrap();
        let proc_addr = GetProcAddress(h_module, s!("LoadLibraryA"))
            .expect("GetProcAddress failed");
        let start_routine: LPTHREAD_START_ROUTINE = Some(
            mem::transmute::<_, unsafe extern "system" fn(*mut core::ffi::c_void) -> u32>(proc_addr)
        );

        // Run LoadLibraryA in new thread
        let h_thread = CreateRemoteThread(
            h_process,
            None,
            0,
            start_routine,
            Some(dll_file_path),
            0,
            None
        )
        .expect("CreateRemoteThread failed.");

        WaitForSingleObject(h_thread, INFINITE);
        
        CloseHandle(h_thread).expect("Close thread handle failed.");
        CloseHandle(h_process).expect("Close process handle failed.");
    }

    println!("[*] Successfully injected dll!");
}
