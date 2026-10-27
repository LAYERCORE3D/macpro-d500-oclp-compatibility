#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import <Metal/Metal.h>
#import <CoreGraphics/CoreGraphics.h>
int main(){@autoreleasepool{
 uint8_t source[64*64*4];for(int y=0;y<64;y++)for(int x=0;x<64;x++){int i=(y*64+x)*4;source[i]=x*4;source[i+1]=y*4;source[i+2]=((x/8+y/8)%2)?200:30;source[i+3]=255;}
 CGColorSpaceRef cs=CGColorSpaceCreateDeviceRGB();CIImage*base=[CIImage imageWithBitmapData:[NSData dataWithBytes:source length:sizeof(source)] bytesPerRow:256 size:CGSizeMake(64,64) format:kCIFormatRGBA8 colorSpace:cs];
 CIContext*cpu=[CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer:@YES}];
 NSArray*filters=@[@"CIColorInvert",@"CIColorControls",@"CIGaussianBlur",@"CISepiaTone",@"CIExposureAdjust",@"CISourceOverCompositing"];
 int count=0,failed=0;
 for(id<MTLDevice>d in MTLCopyAllDevices()){
 CIContext*gpu=[CIContext contextWithMTLDevice:d options:@{kCIContextUseSoftwareRenderer:@NO}];
 for(NSString*name in filters){
 CIFilter*f=[CIFilter filterWithName:name];[f setDefaults];[f setValue:base forKey:kCIInputImageKey];
 if([name isEqual:@"CIGaussianBlur"])[f setValue:@2 forKey:kCIInputRadiusKey];
 if([name isEqual:@"CIColorControls"])[f setValue:@0.6 forKey:kCIInputSaturationKey];
 if([name isEqual:@"CIExposureAdjust"])[f setValue:@0.5 forKey:kCIInputEVKey];
 if([name isEqual:@"CISourceOverCompositing"])[f setValue:[CIImage imageWithColor:[CIColor colorWithRed:0.3 green:0.5 blue:0.7]] forKey:kCIInputBackgroundImageKey];
 CIImage*im=f.outputImage;uint8_t a[64*64*4],b[64*64*4];memset(a,0xa5,sizeof(a));memset(b,0x5a,sizeof(b));
 [cpu render:im toBitmap:a rowBytes:256 bounds:CGRectMake(0,0,64,64) format:kCIFormatRGBA8 colorSpace:cs];
 [gpu render:im toBitmap:b rowBytes:256 bounds:CGRectMake(0,0,64,64) format:kCIFormatRGBA8 colorSpace:cs];
 int maxdiff=0;long total=0;for(int i=0;i<sizeof(a);i++){int diff=abs(a[i]-b[i]);maxdiff=MAX(maxdiff,diff);total+=diff;}
 BOOL ok=maxdiff<=6;count++;if(!ok)failed++;
 NSDictionary*o=@{@"gpu":@(d.registryID),@"filter":name,@"maxDiff":@(maxdiff),@"meanDiff":@((double)total/sizeof(a)),@"ok":@(ok)};puts([[NSString alloc]initWithData:[NSJSONSerialization dataWithJSONObject:o options:0 error:nil]encoding:NSUTF8StringEncoding].UTF8String);fflush(stdout);
 }}CGColorSpaceRelease(cs);printf("cases=%d failures=%d\n",count,failed);return failed?1:0;
}}
