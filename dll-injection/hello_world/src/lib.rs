use windows::core::s;
use windows::Win32::System::SystemServices::*;
use windows::Win32::UI::WindowsAndMessaging::{MessageBoxA, MB_OK};

#[unsafe(no_mangle)]
#[allow(non_snake_case)]
fn DllMain(_: usize, dw_reason: u32, _: usize) -> i32 {
    match dw_reason {
        DLL_PROCESS_ATTACH => attach(),
        DLL_PROCESS_DETACH => (),
        _ => (),
    }

    1
}

fn attach() {
    unsafe {
        MessageBoxA(None, s!("Hello World!"), s!("Hello World DLL"), MB_OK);
    }
}