#cython: language_level=3

cimport cython

@cython.boundscheck(False)
@cython.wraparound(False)

cpdef rgb565_to_uint16(unsigned char[:,:,:] input, unsigned short[:,:] output):
    cdef int x,y
    for y in range(input.shape[0]):
        for x in range(input.shape[1]):
            output[y,x] = ((input[y,x,2] << 8) + (input[y,x,1] << 3) + (input[y,x,0] >> 3))

cpdef rgb565_to_uint8(unsigned char[:,:,:] input, unsigned char[:,:] output):
    cdef int x,y
    cdef unsigned short val
    for y in range(input.shape[0]):
        for x in range(input.shape[1]):
            val = ((input[y,x,2] << 8) + (input[y,x,1] << 3) + (input[y,x,0] >> 3))
            output[y,x] = val >> 4