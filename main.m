//
//  main.m
//  pvr2ccz
//
//  Created by Rocco Bowling on 2/17/14.
//  Copyright (c) 2014 Rocco Bowling. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSDataAdditions.h"

typedef struct {
    unsigned char   sig[4];             // signature. Should be 'CCZ!' 4 bytes
    unsigned short  compression_type;   // should 0
    unsigned short  version;            // should be 2 (although version type==1 is also supported)
    unsigned int    reserved;           // Reserved for users.
    unsigned int    len;                // size of the uncompressed file
} CCZHeader;

enum {
    CCZ_COMPRESSION_ZLIB,               // zlib format.
    CCZ_COMPRESSION_BZIP2,              // bzip2 format (not supported yet)
    CCZ_COMPRESSION_GZIP,               // gzip format (not supported yet)
    CCZ_COMPRESSION_NONE,               // plain (not supported yet)
};

#define CC_HOST_IS_BIG_ENDIAN (bool)(*(unsigned short *)"\0\xff" < 0x100)
#define CC_SWAP32(i)  ((i & 0x000000ff) << 24 | (i & 0x0000ff00) << 8 | (i & 0x00ff0000) >> 8 | (i & 0xff000000) >> 24)
#define CC_SWAP16(i)  ((i & 0x00ff) << 8 | (i &0xff00) >> 8)
#define CC_SWAP_INT32_LITTLE_TO_HOST(i) ((CC_HOST_IS_BIG_ENDIAN == true)? CC_SWAP32(i) : (i) )
#define CC_SWAP_INT16_LITTLE_TO_HOST(i) ((CC_HOST_IS_BIG_ENDIAN == true)? CC_SWAP16(i) : (i) )
#define CC_SWAP_INT32_BIG_TO_HOST(i)    ((CC_HOST_IS_BIG_ENDIAN == true)? (i) : CC_SWAP32(i) )
#define CC_SWAP_INT16_BIG_TO_HOST(i)    ((CC_HOST_IS_BIG_ENDIAN == true)? (i):  CC_SWAP16(i) )

#pragma mark -


void usage()
{
    fprintf(stdout, "pvr2ccz <path to pvr file>");
    exit(1);
}

void extractPVR(const char * basePath)
{
    NSString * cczPath = [NSString stringWithUTF8String:basePath];
    NSString * pvrPath = [cczPath stringByDeletingPathExtension];
    
    if([[pvrPath pathExtension] isEqualToString:@"pvr"] == NO)
    {
        pvrPath = [pvrPath stringByAppendingPathExtension:@"pvr"];
    }
    
    NSData * cczData = [NSData dataWithContentsOfFile:cczPath];
    CCZHeader * header = (CCZHeader *)[cczData bytes];
    unsigned int len = CC_SWAP_INT32_BIG_TO_HOST(header->len);
    
    NSData * compressedData = [NSData dataWithBytesNoCopy:header+1 length:len freeWhenDone:NO];
    NSData * uncompressedData = NULL;
    
    if(CC_SWAP_INT16_BIG_TO_HOST(header->compression_type) == CCZ_COMPRESSION_ZLIB ||
       CC_SWAP_INT16_BIG_TO_HOST(header->compression_type) == CCZ_COMPRESSION_GZIP)
    {
        uncompressedData = [compressedData zipInflate];
    }
    else if(CC_SWAP_INT16_BIG_TO_HOST(header->compression_type) == CCZ_COMPRESSION_BZIP2)
    {
        uncompressedData = [compressedData bzipInflate];
    }
    
    [uncompressedData writeToFile:pvrPath atomically:NO];
}

void createCCZ(const char * basePath)
{
    NSString * pvrPath = [NSString stringWithUTF8String:basePath];
    NSString * cczPath = [pvrPath stringByAppendingPathExtension:@"ccz"];
    
    // 0) Confirm the requested file exists
    if(![[NSFileManager defaultManager] fileExistsAtPath:pvrPath isDirectory:NULL])
    {
        fprintf(stderr, "File does not exist");
        exit(255);
    }
    
    // 1) Create the .zip file
    NSData * uncompressedPVRData = [NSData dataWithContentsOfFile:pvrPath];
    NSData * compressedPVRData = [uncompressedPVRData zipDeflate];
    
    // 2) Create the .ccz file
    NSMutableData * cczData = [NSMutableData data];
    CCZHeader header = {0};
    
    header.sig[0] = 'C';
    header.sig[1] = 'C';
    header.sig[2] = 'Z';
    header.sig[3] = '!';
    
    header.compression_type = CC_SWAP16(CCZ_COMPRESSION_ZLIB);
    header.version = CC_SWAP16(1);
    
    header.len = CC_SWAP32((unsigned int)[uncompressedPVRData length]);
    
    [cczData appendBytes:&header length:sizeof(header)];
    [cczData appendData:compressedPVRData];
    
    [cczData writeToFile:cczPath atomically:NO];
}

int main(int argc, const char * argv[])
{

    @autoreleasepool
    {
        if(argc < 2)
        {
            usage();
        }
        
        int ch;
        while ((ch = getopt(argc, (char * const *)argv, "x")) != -1)
        {
            switch (ch)
            {
                case '?':
                    usage();
            }
        }
        argc -= optind;
        argv += optind;
        
        NSString * basePath = [NSString stringWithUTF8String:argv[0]];
        
        if([[basePath pathExtension] isEqualToString:@"ccz"])
        {
            extractPVR(argv[0]);
        }
        else if([[basePath pathExtension] isEqualToString:@"pvr"])
        {
            createCCZ(argv[0]);
        }
        
    }
    return 0;
}

