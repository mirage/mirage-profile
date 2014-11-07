/* Copyright (c) 2014 Thomas Leonard */

#include <stdint.h>
#include <caml/mlvalues.h>
#include <caml/fail.h>
#include <caml/bigarray.h>

/* Defined in minios headers. Easier than getting OASIS to work with pkg-config... */
uint64_t monotonic_clock(void);

/* Write the current time to bigarray[idx] as a little-endian uint64 (nanoseconds). */
CAMLprim value stub_mprof_get_monotonic_time(value bigarray, value index)
{
	uint64_t t;
	long idx = Long_val(index);
	char *buffer = Data_bigarray_val(bigarray);
	int buffer_len = Bigarray_val(bigarray)->dim[0];

	t = monotonic_clock();

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
