
#import "NSDataAdditions.h"

#import <CommonCrypto/CommonDigest.h>

#import "bzlib.h"

@implementation NSData (NSDataAdditions)

#pragma mark -
#pragma mark ZIP

- (NSData *)zipDeflate:(int)strategy
{
	if ([self length] == 0) return self;
    
    uLongf bufferSize = compressBound([self length]);
    Bytef * outBuffer = malloc(bufferSize);
    uLongf outBufferSize = bufferSize;
	
    compress(outBuffer, &outBufferSize, [self bytes], [self length]);
    
    return [NSData dataWithBytesNoCopy:outBuffer length:outBufferSize freeWhenDone:YES];
}

- (NSData *)zipDeflate
{
    return [self zipDeflate:Z_DEFAULT_STRATEGY];
}

- (NSData *)zipInflate
{
	if ([self length] == 0) return self;
	
	unsigned full_length = (unsigned int)[self length];
	unsigned half_length = (unsigned int)[self length] / 2;
	
	NSMutableData *decompressed = [NSMutableData dataWithLength: full_length + half_length];
	BOOL done = NO;
	int status;
	
	z_stream strm;
	strm.next_in = (Bytef *)[self bytes];
	strm.avail_in = (unsigned int)[self length];
	strm.total_out = 0;
	strm.zalloc = Z_NULL;
	strm.zfree = Z_NULL;
	
	if (inflateInit2(&strm, (15+32)) != Z_OK) return nil;
	while (!done)
	{
		// Make sure we have enough room and reset the lengths.
		if (strm.total_out >= [decompressed length])
			[decompressed increaseLengthBy: half_length];
		strm.next_out = (Bytef *)[decompressed mutableBytes] + strm.total_out;
		strm.avail_out = (unsigned int)([decompressed length] - strm.total_out);
		
		// Inflate another chunk.
		status = inflate (&strm, Z_SYNC_FLUSH);
		if (status == Z_STREAM_END) done = YES;
		else if (status != Z_OK) break;
	}
	if (inflateEnd (&strm) != Z_OK) return nil;
	
	// Set real length.
	if (done)
	{
		[decompressed setLength: strm.total_out];
		return [NSData dataWithData: decompressed];
	}
	else return nil;
}

#pragma mark -
#pragma mark bzip2



- (NSData *) bzipDeflate:(int)compression
{
	int bzret, buffer_size = 1000000;
	bz_stream stream = { 0 };
	stream.next_in = (char *)[self bytes];
	stream.avail_in = (unsigned int)[self length];
	
	NSMutableData * buffer = [NSMutableData dataWithLength:buffer_size];
	stream.next_out = [buffer mutableBytes];
	stream.avail_out = buffer_size;
	
	NSMutableData * compressed = [NSMutableData data];
	
	BZ2_bzCompressInit(&stream, compression, 0, 0);
	@try {
		do {
			bzret = BZ2_bzCompress(&stream, (stream.avail_in) ? BZ_RUN : BZ_FINISH);
			if (bzret != BZ_RUN_OK && bzret != BZ_STREAM_END)
				@throw [NSException exceptionWithName:@"bzip2" reason:@"BZ2_bzCompress failed" userInfo:nil];
            
			[compressed appendBytes:[buffer bytes] length:(buffer_size - stream.avail_out)];
			stream.next_out = [buffer mutableBytes];
			stream.avail_out = buffer_size;
		} while(bzret != BZ_STREAM_END);
	}
	@finally {
		BZ2_bzCompressEnd(&stream);
	}
	
	return compressed;
}

- (NSData *) bzipDeflate
{
    return [self bzipDeflate:9];
}

- (NSData *) bzipInflate
{
	int bzret;
	bz_stream stream = { 0 };
	stream.next_in = (char *)[self bytes];
	stream.avail_in = (unsigned int)[self length];
	
	const int buffer_size = 10000;
	NSMutableData * buffer = [NSMutableData dataWithLength:buffer_size];
	stream.next_out = [buffer mutableBytes];
	stream.avail_out = buffer_size;
	
	NSMutableData * decompressed = [NSMutableData data];
	
	BZ2_bzDecompressInit(&stream, 0, NO);
	@try {
		do {
			bzret = BZ2_bzDecompress(&stream);
			if (bzret != BZ_OK && bzret != BZ_STREAM_END)
            {
                BZ2_bzDecompressEnd(&stream);
                return NULL;
            }
            
            if((buffer_size - stream.avail_out) == 0)
            {
                BZ2_bzDecompressEnd(&stream);
                return NULL;
            }
            
			[decompressed appendBytes:[buffer bytes] length:(buffer_size - stream.avail_out)];
			stream.next_out = [buffer mutableBytes];
			stream.avail_out = buffer_size;
		} while(bzret != BZ_STREAM_END);
	}
	@finally {
		BZ2_bzDecompressEnd(&stream);
	}
	
	return decompressed;
}

@end

