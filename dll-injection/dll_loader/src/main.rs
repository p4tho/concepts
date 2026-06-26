use windows::Win32::System::LibraryLoader::LoadLibraryA;
use windows::core::{Result, s};
use windows::Win32::Foundation::HMODULE;

fn main() {
    let dll_file_path = s!("hello_world.dll");

    println!("[*] Loading DLL at {:?}", dll_file_path);

    let hmod: Result<HMODULE> = unsafe { LoadLibraryA(dll_file_path) };
    match hmod {
        Ok(h) => println!("[+] Module injected! Handle: {:?}", h),
        Err(e) => println!("[!] Error injecting module, {e}"),
    }
}