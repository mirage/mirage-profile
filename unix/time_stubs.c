/* Copyright (c) 2014 Thomas Leonard */

#include <stdint.h>
#include <time.h>
#include <caml/mlvalues.h>
#include <caml/fail.h>
#include <caml/bigarray.h>

#ifdef __MACH__
/* http://stackoverflow.com/questions/11680461/monotonic-clock-on-osx */
#include <mach/clock.h>
#include <mach/mach.h>
#endif

/* Write the current time to bigarray[idx] as a little-endian uint64 (nanoseconds). */
CAMLprim value stub_mprof_get_monotonic_time(value bigarray, value index)
{
	uint64_t t;
	long idx = Long_val(index);
	char *buffer = Data_bigarray_val(bigarray);
	int buffer_len = Bigarray_val(bigarray)->dim[0];
#ifdef __MACH__
	clock_serv_t cclock;
	mach_timespec_t tv;

	host_get_clock_service(mach_host_self(), SYSTEM_CLOCK, &cclock);
	clock_get_time(cclock, &tv);
	mach_port_deallocate(mach_task_self(), cclock);
#else
	struct timespec tv;
	clock_gettime(CLOCK_MONOTONIC, &tv);
#endif
	t = ((uint64_t) tv.tv_sec) * 1000000000 + tv.tv_nsec;
	if (idx < 0 || idx + 7 >= buffer_len) caml_array_bound_error();

	buffer[idx] = t & 0xff;
	buffer[idx + 1] = (t >> 8) & 0xff;
	buffer[idx + 2] = (t >> 16) & 0xff;
	buffer[idx + 3] = (t >> 24) & 0xff;
	buffer[idx + 4] = (t >> 32) & 0xff;
	buffer[idx + 5] = (t >> 40) & 0xff;
	buffer[idx + 6] = (t >> 48) & 0xff;
	buffer[idx + 7] = (t >> 56) & 0xff;

	return Val_unit;
}
