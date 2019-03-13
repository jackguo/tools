//
// GPU Info
// Based on freevram and MetalInfo tools.
// See: https://stackoverflow.com/questions/3783030/free-vram-on-os-x
// also see: https://github.com/acidanthera/WhateverGreen/tree/master/Tools/GPUInfo
// 

#include <stdio.h>
#include <stdint.h>
#include <dlfcn.h>

#include <objc/runtime.h>
#include <objc/message.h>

#include <IOKit/graphics/IOGraphicsLib.h>
#include <CoreFoundation/CoreFoundation.h>
#include <Foundation/Foundation.h>

void printKeys(NSMutableDictionary *d);
void printEntries(CFMutableDictionaryRef ref, int indent);
void printNumeric(CFNumberRef ref);

void currentFreeVRAM() {
  kern_return_t krc;  
  mach_port_t masterPort;
  krc = IOMasterPort(bootstrap_port, &masterPort);

  uint64_t total = 0;

  if (krc == KERN_SUCCESS) {
    CFMutableDictionaryRef pattern = IOServiceMatching(kIOAcceleratorClassName);

    io_iterator_t deviceIterator;
    krc = IOServiceGetMatchingServices(masterPort, pattern, &deviceIterator);
    if (krc == KERN_SUCCESS) {
      io_object_t object;
      while ((object = IOIteratorNext(deviceIterator))) {
        CFMutableDictionaryRef properties = NULL;
        krc = IORegistryEntryCreateCFProperties(object, &properties, kCFAllocatorDefault, (IOOptionBits)0);
        if (krc == KERN_SUCCESS) {
          const void *total_vram_number = CFDictionaryGetValue(properties, CFSTR("VRAM,totalMB"));
          if (total_vram_number) {
            CFNumberGetValue((CFNumberRef) total_vram_number, kCFNumberSInt64Type, total);
            printf("Total VRAM availabile: %zu MB\n", (size_t)total);
          }
          CFMutableDictionaryRef perf_properties = (CFMutableDictionaryRef)CFDictionaryGetValue(properties, CFSTR("PerformanceStatistics") );

          printEntries(perf_properties, 0);
          // Look for a number of keys (this is mostly reverse engineering and best-guess effort)
          const void *free_vram_number = CFDictionaryGetValue(perf_properties, CFSTR("vramFreeBytes"));
          if (free_vram_number) {
            ssize_t free_vram;
            CFNumberGetValue((CFNumberRef)free_vram_number, kCFNumberSInt64Type, &free_vram);
            printf("Free VRAM availabile: %zu MB (%zu Bytes)\n", (size_t)(free_vram/(1024*1024)), (size_t)free_vram); 
          }
        }
        if (properties) {
          CFRelease(properties);
        }
        IOObjectRelease(object);
      }
      IOObjectRelease(deviceIterator);
    }
  }
}

int main() {
  /*
    uint64_t total_vram = 0;
    if (total_vram > 0)
 
  */
  currentFreeVRAM();
  
  void *mtl = dlopen("/System/Library/Frameworks/Metal.framework/Metal", RTLD_LAZY);
  id (*create_dev)(void) = (id (*)(void))dlsym(mtl, "MTLCreateSystemDefaultDevice");
  if (create_dev) {
    id device = create_dev();
    if (device) {
      id name     = objc_msgSend(device, sel_registerName("name"));
      id lowpower = objc_msgSend(device, sel_registerName("isLowPower"));
      id headless = objc_msgSend(device, sel_registerName("isHeadless"));
      printf("Metal device name: %s\n", (const char *)objc_msgSend(name, sel_registerName("UTF8String")));
      printf("Low Power: %s\n", lowpower ? "Yes" : "No");
      printf("Headless: %s\n", headless ? "Yes" : "No");
    } else {
      printf("Metal is not supported by your hardware!\n");
    }
  } else {
    printf("Metal is not supported by this operating system!\n");
  }
}

void printKeys(NSMutableDictionary *d) {
  printf("---------start dictionary key printing-------\n");
  for (NSString *key in d) {
    printf("%s\n", [key UTF8String]);
  }
  printf("---------end dictionary key printing---------\n");
}

void printEntries(CFMutableDictionaryRef ref, int indent) {
  printf("---------start dictionary entry printing---------\n");

  size_t c = CFDictionaryGetCount(ref);
  const void **keys = calloc(c, sizeof(void *));
  const void **values = calloc(c, sizeof(void *));
  CFDictionaryGetKeysAndValues(ref, keys, values);
  for (int j = 0; j < c; ++j) {
    for (int i = 0; i < indent; ++i) {
      printf(" ");
    }

    printf("%s : ", CFStringGetCStringPtr(keys[j], kCFStringEncodingUTF8));
    //    if (value CFStringRef) {
    //    @try {
    //  printf("%s\n", CFStringGetCStringPtr(values[j], kCFStringEncodingUTF8));
    //} @catch (NSException *e) {
      printNumeric(values[j]);
      printf("\n");
      //}
      /*   } else if ([value isKindOfClass:[CFNumberRef class]]) {
      printNumeric(value);
      printf("\n");
    } else if ([value isKindOfClass:[CFMutableDictionaryRef class]]) {
      printEntries(value, indent + 4);
    }
      */
  }

  printf("--------end dictionary entry printing------------\n");
  free(keys);
  free(values);
}

void printNumeric(CFNumberRef ref) {
  CFNumberType type = CFNumberGetType(ref);
  
  if (CFNumberIsFloatType(ref)) {
    double n;
    CFNumberGetValue(ref, type, &n);
    printf("%g", n);
  } else {
    int64_t n;
    CFNumberGetValue(ref, type, &n);
    printf("%lld", n);
  }
  
}
