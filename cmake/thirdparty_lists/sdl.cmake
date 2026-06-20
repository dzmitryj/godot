# MANUAL list (not from extract_thirdparty.py): the Windows SDL source subset transcribed from
# drivers/sdl/SCsub (common + HIDAPI + core/windows). Re-sync if that SCsub changes.
set(GODOT_TP_SDL_SOURCES
  # common
  sdl/SDL.c sdl/SDL_assert.c sdl/SDL_error.c sdl/SDL_guid.c sdl/SDL_hashtable.c sdl/SDL_hints.c
  sdl/SDL_list.c sdl/SDL_log.c sdl/SDL_properties.c sdl/SDL_utils.c
  sdl/atomic/SDL_atomic.c sdl/atomic/SDL_spinlock.c
  sdl/events/SDL_events.c sdl/events/SDL_eventwatch.c
  sdl/haptic/SDL_haptic.c sdl/io/SDL_iostream.c
  sdl/joystick/SDL_gamepad.c sdl/joystick/SDL_joystick.c sdl/joystick/SDL_steam_virtual_gamepad.c
  sdl/joystick/controller_type.c
  sdl/libm/e_atan2.c sdl/libm/e_exp.c sdl/libm/e_fmod.c sdl/libm/e_log.c sdl/libm/e_log10.c
  sdl/libm/e_pow.c sdl/libm/e_rem_pio2.c sdl/libm/e_sqrt.c sdl/libm/k_cos.c sdl/libm/k_rem_pio2.c
  sdl/libm/k_sin.c sdl/libm/k_tan.c sdl/libm/s_atan.c sdl/libm/s_copysign.c sdl/libm/s_cos.c
  sdl/libm/s_fabs.c sdl/libm/s_floor.c sdl/libm/s_isinf.c sdl/libm/s_isinff.c sdl/libm/s_isnan.c
  sdl/libm/s_isnanf.c sdl/libm/s_modf.c sdl/libm/s_scalbn.c sdl/libm/s_sin.c sdl/libm/s_tan.c
  sdl/sensor/SDL_sensor.c sdl/sensor/dummy/SDL_dummysensor.c
  sdl/stdlib/SDL_crc16.c sdl/stdlib/SDL_crc32.c sdl/stdlib/SDL_getenv.c sdl/stdlib/SDL_iconv.c
  sdl/stdlib/SDL_malloc.c sdl/stdlib/SDL_memcpy.c sdl/stdlib/SDL_memmove.c sdl/stdlib/SDL_memset.c
  sdl/stdlib/SDL_mslibc.c sdl/stdlib/SDL_murmur3.c sdl/stdlib/SDL_qsort.c sdl/stdlib/SDL_random.c
  sdl/stdlib/SDL_stdlib.c sdl/stdlib/SDL_string.c sdl/stdlib/SDL_strtokr.c
  sdl/thread/SDL_thread.c sdl/timer/SDL_timer.c
  # HIDAPI
  sdl/hidapi/SDL_hidapi.c
  sdl/joystick/hidapi/SDL_hidapi_combined.c sdl/joystick/hidapi/SDL_hidapi_gamecube.c
  sdl/joystick/hidapi/SDL_hidapijoystick.c sdl/joystick/hidapi/SDL_hidapi_luna.c
  sdl/joystick/hidapi/SDL_hidapi_ps3.c sdl/joystick/hidapi/SDL_hidapi_ps4.c
  sdl/joystick/hidapi/SDL_hidapi_ps5.c sdl/joystick/hidapi/SDL_hidapi_rumble.c
  sdl/joystick/hidapi/SDL_hidapi_shield.c sdl/joystick/hidapi/SDL_hidapi_stadia.c
  sdl/joystick/hidapi/SDL_hidapi_steam.c sdl/joystick/hidapi/SDL_hidapi_steamdeck.c
  sdl/joystick/hidapi/SDL_hidapi_steam_hori.c sdl/joystick/hidapi/SDL_hidapi_switch.c
  sdl/joystick/hidapi/SDL_hidapi_wii.c sdl/joystick/hidapi/SDL_hidapi_xbox360.c
  sdl/joystick/hidapi/SDL_hidapi_xbox360w.c sdl/joystick/hidapi/SDL_hidapi_xboxone.c
  # core/windows
  sdl/core/windows/SDL_gameinput.c sdl/core/windows/SDL_hid.c sdl/core/windows/SDL_immdevice.c
  sdl/core/windows/SDL_windows.c sdl/core/windows/SDL_xinput.c sdl/core/windows/pch.c
  sdl/haptic/windows/SDL_dinputhaptic.c sdl/haptic/windows/SDL_windowshaptic.c
  sdl/joystick/windows/SDL_dinputjoystick.c sdl/joystick/windows/SDL_rawinputjoystick.c
  sdl/joystick/windows/SDL_windows_gaming_input.c sdl/joystick/windows/SDL_windowsjoystick.c
  sdl/joystick/windows/SDL_xinputjoystick.c
  sdl/thread/generic/SDL_syscond.c sdl/thread/generic/SDL_sysrwlock.c
  sdl/sensor/windows/SDL_windowssensor.c
  sdl/thread/windows/SDL_syscond_cv.c sdl/thread/windows/SDL_sysmutex.c
  sdl/thread/windows/SDL_sysrwlock_srw.c sdl/thread/windows/SDL_syssem.c
  sdl/thread/windows/SDL_systhread.c sdl/thread/windows/SDL_systls.c
  sdl/timer/windows/SDL_systimer.c
)
