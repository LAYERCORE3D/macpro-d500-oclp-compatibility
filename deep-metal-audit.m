#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <CoreImage/CoreImage.h>
#import <CoreGraphics/CoreGraphics.h>
#include <math.h>
static void emit(NSDictionary*d){puts([[NSString alloc]initWithData:[NSJSONSerialization dataWithJSONObject:d options:0 error:nil]encoding:NSUTF8StringEncoding].UTF8String);fflush(stdout);}
int main(){@autoreleasepool{
 int failures=0,cases=0;
 for(id<MTLDevice>d in MTLCopyAllDevices()){
  id<MTLCommandQueue>q=[d newCommandQueue];
  for(NSNumber*fmt in @[@(MTLPixelFormatRGBA8Unorm),@(MTLPixelFormatBGRA8Unorm)])for(NSNumber*sc in @[@1,@2,@4,@8])for(NSNumber*priv in @[@NO,@YES]){
   NSUInteger samples=sc.unsignedIntegerValue;if(![d supportsTextureSampleCount:samples])continue;
   MTLTextureDescriptor*desc=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:fmt.unsignedIntegerValue width:127 height:63 mipmapped:NO];desc.storageMode=priv.boolValue?MTLStorageModePrivate:MTLStorageModeManaged;desc.usage=MTLTextureUsageRenderTarget|MTLTextureUsageShaderRead;
   id<MTLTexture>out=[d newTextureWithDescriptor:desc],ms=nil;
   if(samples>1){desc.textureType=MTLTextureType2DMultisample;desc.sampleCount=samples;desc.storageMode=MTLStorageModePrivate;ms=[d newTextureWithDescriptor:desc];}
   if(!out||(samples>1&&!ms)){emit(@{@"test":@"texture-allocation",@"ok":@NO});return 2;}
   id<MTLCommandBuffer>cb=[q commandBuffer];MTLRenderPassDescriptor*p=[MTLRenderPassDescriptor renderPassDescriptor];p.colorAttachments[0].texture=ms?:out;p.colorAttachments[0].clearColor=MTLClearColorMake(0.25,0.5,0.75,1);p.colorAttachments[0].loadAction=MTLLoadActionClear;p.colorAttachments[0].storeAction=MTLStoreActionStore;
   if(ms){p.colorAttachments[0].resolveTexture=out;p.colorAttachments[0].storeAction=MTLStoreActionStoreAndMultisampleResolve;}
   [[cb renderCommandEncoderWithDescriptor:p] endEncoding];id<MTLBuffer>b=[d newBufferWithLength:512*63 options:MTLResourceStorageModeManaged];id<MTLBlitCommandEncoder>bl=[cb blitCommandEncoder];[bl copyFromTexture:out sourceSlice:0 sourceLevel:0 sourceOrigin:MTLOriginMake(0,0,0) sourceSize:MTLSizeMake(127,63,1) toBuffer:b destinationOffset:0 destinationBytesPerRow:512 destinationBytesPerImage:0];[bl synchronizeResource:b];[bl endEncoding];[cb commit];[cb waitUntilCompleted];
   int bad=0;uint8_t*bytes=b.contents;BOOL bgra=fmt.unsignedIntegerValue==MTLPixelFormatBGRA8Unorm;
   for(int y=0;y<63;y++)for(int x=0;x<127;x++){uint8_t*v=bytes+512*y+4*x;if(abs(v[0]-(bgra?191:64))>1||abs(v[1]-128)>1||abs(v[2]-(bgra?64:191))>1||v[3]!=255)bad++;}
   BOOL ok=!bad&&!cb.error;cases++;if(!ok)failures++;emit(@{@"test":@"texture-msaa-readback",@"gpu":@(d.registryID),@"format":fmt,@"samples":sc,@"private":priv,@"badPixels":@(bad),@"ok":@(ok),@"error":cb.error.description?:@""});
  }
  // Arithmetic with nonuniform data, checked against a CPU reference.
  NSError*err=nil;MTLCompileOptions*opt=[MTLCompileOptions new];opt.languageVersion=MTLLanguageVersion2_0;
  id<MTLLibrary>lib=[d newLibraryWithSource:@"#include <metal_stdlib>\nusing namespace metal;kernel void calc(device uint*a[[buffer(0)]],device uint*b[[buffer(1)]],uint i[[thread_position_in_grid]]){if(i<4096)b[i]=a[i]*3u+7u;}" options:opt error:&err];
  id<MTLComputePipelineState>pipe=[d newComputePipelineStateWithFunction:[lib newFunctionWithName:@"calc"] error:&err];if(!pipe){fprintf(stderr,"%s\n",err.description.UTF8String);return 3;}
  id<MTLBuffer>a=[d newBufferWithLength:16384 options:MTLResourceStorageModeManaged],b=[d newBufferWithLength:16384 options:MTLResourceStorageModeManaged];uint32_t*input=a.contents;for(int i=0;i<4096;i++)input[i]=(i*97u)^0x123456u;[a didModifyRange:NSMakeRange(0,16384)];
  id<MTLCommandBuffer>cb=[q commandBuffer];id<MTLComputeCommandEncoder>c=[cb computeCommandEncoder];[c setComputePipelineState:pipe];[c setBuffer:a offset:0 atIndex:0];[c setBuffer:b offset:0 atIndex:1];[c dispatchThreadgroups:MTLSizeMake(64,1,1) threadsPerThreadgroup:MTLSizeMake(64,1,1)];[c endEncoding];id<MTLBlitCommandEncoder>bl=[cb blitCommandEncoder];[bl synchronizeResource:b];[bl endEncoding];[cb commit];[cb waitUntilCompleted];int wrong=0;for(int i=0;i<4096;i++)if(((uint32_t*)b.contents)[i]!=input[i]*3u+7u)wrong++;
  BOOL ok=!wrong&&!cb.error;cases++;if(!ok)failures++;emit(@{@"test":@"compute-reference",@"gpu":@(d.registryID),@"wrong":@(wrong),@"ok":@(ok)});
 }
 emit(@{@"cases":@(cases),@"failures":@(failures)});return failures?4:0;
}}
