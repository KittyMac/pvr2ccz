
#import <Foundation/Foundation.h>
#import <zlib.h>

@interface NSData (NSData2Additions)

- (NSData *) zipDeflate:(int)strategy;
- (NSData *) zipDeflate;
- (NSData *) zipInflate;

- (NSData *) bzipDeflate:(int)compression;
- (NSData *) bzipDeflate;
- (NSData *) bzipInflate;

@end
