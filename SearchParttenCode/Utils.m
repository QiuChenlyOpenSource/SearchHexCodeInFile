//
//  Utils.m
//  SearchParttenCode
//
//  Created by qiuchenly on 2023/10/13.
//

#import <Foundation/Foundation.h>
#include "Utils.h"
#include <objc/runtime.h>
#import <mach-o/dyld.h>
#import <SwiftUI/SwiftUI.h>
#import <AppKit/AppKit.h>
#import "Utils.h"
#include <sys/types.h>
#include <sys/sysctl.h>
#import "mach-o/fat.h"
#import "mach-o/getsect.h"

@implementation Utils

NSString *checkCPUSubType(void) {
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *machineString = [NSString stringWithCString:machine encoding:NSUTF8StringEncoding];
    free(machine);
    NSLog(@"当前CPU类型是 %@", machineString);
    return machineString;
}


/**
 * 是否为X86机器 否则就是arm64机器
 */
BOOL isX86(void) {
    return [checkCPUSubType() isEqualToString:@"x86_64"];
}

/**
 * 获取指向 x86 架构的文件的文件偏移量
 * @param desiredCpuType CPU_TYPE_X86
 * @param baseName 文件序号
 * @return 返回当前架构的代码开始段开始地址
 */
uint32_t getArchFileOffset(const uint32_t desiredCpuType, const char *baseName) {
    NSLog(@"==== 得到了 %s", baseName);
    NSArray<NSDictionary *> *architecturesInfo = getArchitecturesInfoForFile([NSString stringWithUTF8String:baseName]);

    for (NSDictionary *archInfo in architecturesInfo) {
        cpu_type_t cpuType = [archInfo[@"cpuType"] unsignedIntValue];
        uint32_t offset = [archInfo[@"offset"] unsignedIntValue];

        if (cpuType == desiredCpuType) {
            return offset;
        } else
            continue;
    }
    return 0;
}

/**
 * 自动获取当前架构的文件相对内存地址偏移
 * @param inxForArchImage 镜像名称
 * @return 返回当前处理器代码偏移段地址
 */
uint32_t getCurrentArchFileOffset(const char* inxForArchImage) {
    const uint32_t desiredCpuType = isX86() ? CPU_TYPE_X86_64 : CPU_TYPE_ARM64;
    return getArchFileOffset(desiredCpuType, inxForArchImage);
}

/**
 * 文件偏移Magic头
 */
const long ARCH_FAT_SIZE = 4294967296;//0x100000000

/**
 * 转换文件偏移到内存地址偏移 无0x10000000偏移
 * @param codeOffset
 * @param fileOffset
 * @return
 */
long getRealFileOffset2RAMOffsetA(long codeOffset, long fileOffset) {
    return codeOffset - fileOffset;
}

/**
 * 转换文件偏移到内存地址偏移
 * @param codeOffset 代码偏移量
 * @param fileOffset 文件全局偏移量
 * @return long var
 */
long getRealFileOffset2RAMOffset(long codeOffset, long fileOffset) {
    return getRealFileOffset2RAMOffsetA(codeOffset, fileOffset) + ARCH_FAT_SIZE;
}

/**
 * 从文件中寻找Hex数据串位置
 * @param filePath 文件路径
 * @param searchHex 搜索的hex字符串 01 02 03 04 AF 这种数据即可 每个字节用空格空开
 * @return 返回数据index
 */
NSArray<NSNumber *> *findOffsetsForHexInFile(NSString *filePath, NSString *searchHex) {
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:filePath];
    NSMutableArray<NSNumber *> *offsets = [NSMutableArray array];

    if (fileHandle) {
        NSData *fileData = [fileHandle readDataToEndOfFile];
        NSArray *lst = [searchHex componentsSeparatedByString:@" "];
        NSData *searchData = dataFromHexString(searchHex);

        if (searchData) {
            NSUInteger searchLength = [searchData length];
            NSUInteger fileLength = [fileData length];
            NSUInteger searchIndex = 0;

            for (NSUInteger i = 0; i < fileLength; i++) {
                uint8_t currentByte = ((const uint8_t *) [fileData bytes])[i];

                if (currentByte == ((const uint8_t *) [searchData bytes])[searchIndex]) {
                    searchIndex++;

                    if (searchIndex == searchLength) {
                        [offsets addObject:@(i - lst.count + 1)];
                        searchIndex = 0;
                    }
                } else {
                    searchIndex = 0;
                }
            }
        } else {
            NSLog(@"Invalid search hex string: %@", searchHex);
        }

        [fileHandle closeFile];
    } else {
        NSLog(@"Failed to open file at path: %@", filePath);
    }

    return [offsets copy];
}

NSArray<NSNumber *> *findOffsetsForHexInCurrentFile(NSString *searchHex) {
    return findOffsetsForHexInFile([NSString stringWithUTF8String:_dyld_get_image_name(0)], searchHex);
}

/**
 * 从Mach-O中读取文件架构信息
 * @param filePath 文件路径
 * @return 返回文件中所有架构列表 只能分析FAT架构文件 Mach-O 64位文件解析不了 会死循环
 */
NSArray<NSDictionary *> *getArchitecturesInfoForFile(NSString *filePath) {
    NSMutableArray < NSDictionary * > *architecturesInfo = [NSMutableArray array];

    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:filePath];
    NSData *fileData = [fileHandle readDataOfLength:sizeof(struct fat_header)];

    if (fileData) {
        const struct fat_header *header = (const struct fat_header *) [fileData bytes];
        uint32_t nfat_arch = OSSwapBigToHostInt32(header->nfat_arch);
        
        NSLog(@"==== nfat_arch = %i = %i",nfat_arch,header->nfat_arch);

        for (uint32_t i = 0; i < nfat_arch; i++) {
            NSData *archData = [fileHandle readDataOfLength:sizeof(struct fat_arch)];
            const struct fat_arch *arch = (const struct fat_arch *) [archData bytes];

            cpu_type_t cpuType = OSSwapBigToHostInt32(arch->cputype);
            cpu_subtype_t cpuSubtype = OSSwapBigToHostInt32(arch->cpusubtype);
            uint32_t offset = OSSwapBigToHostInt32(arch->offset);
            uint32_t size = OSSwapBigToHostInt32(arch->size);

            NSDictionary *archInfo = @{
                    @"cpuType": @(cpuType),
                    @"cpuSubtype": @(cpuSubtype),
                    @"offset": @(offset),
                    @"size": @(size)
            };

            [architecturesInfo addObject:archInfo];
        }
    } else {
        NSLog(@"Failed to read file at path: %@", filePath);
    }

    [fileHandle closeFile];

    return [architecturesInfo copy];
}


/**
 * HexString2Data
 * @param hexString
 * @return
 */
NSData *dataFromHexString(NSString *hexString) {
    NSMutableData *data = [NSMutableData new];
    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    hexString = [[hexString componentsSeparatedByCharactersInSet:whitespace] componentsJoinedByString:@""];

    for (NSUInteger i = 0; i < [hexString length]; i += 2) {
        NSString *byteString = [hexString substringWithRange:NSMakeRange(i, 2)];
        if ([byteString isEqualToString:@"??"]) {
            //这里为了适配?? 通配符 直接改成144 0x90 nop 但是这么写在匹配NOP代码的时候可能会出现误判的问题
            uint8_t byte = (uint8_t) 144;
            [data appendBytes:&byte length:1];
            continue;
        }
        NSScanner *scanner = [NSScanner scannerWithString:byteString];
        unsigned int byteValue;
        [scanner scanHexInt:&byteValue];
        uint8_t byte = (uint8_t) byteValue;
//        NSLog(@"byteString = %@, byteValue = %i", byteString,byte);
        [data appendBytes:&byte length:1];
    }
//    NSLog(@"byteString = %@", [data copy]);
    return [data copy];
}

NSArray<NSNumber *> *findOffsetsForWildcardHexInFile(NSString *filePath, NSString *searchHex, NSUInteger matchCount) {
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:filePath];
    NSMutableArray<NSNumber *> *offsets = [NSMutableArray array];

    if (fileHandle) {
        NSData *fileData = [fileHandle readDataToEndOfFile];
        NSData *searchData = dataFromHexString(searchHex);
//        NSLog(@"==== fileData = %@,searchData = %@",fileData,searchData);

        if (searchData) {
            NSUInteger searchLength = [searchData length];
            NSUInteger fileLength = [fileData length];
            NSUInteger matchCounter = 0;
            
            for (NSUInteger i = 0; i < fileLength - searchLength + 1; i++) {
                 BOOL isMatch = YES;
                 for (NSUInteger j = 0; j < searchLength; j++) {
                     uint8_t fileByte = ((const uint8_t *)[fileData bytes])[i + j];
                     uint8_t searchByte = ((const uint8_t *)[searchData bytes])[j];
                     if (searchByte != 0x90 && fileByte != searchByte) {
                         isMatch = NO;
                         break;
                     }
                 }
                 if (isMatch) {
                     [offsets addObject:@(i)];
                     matchCounter++;
                     if (matchCounter >= matchCount) {
                         break;
                     }
                 }
             }
        } else {
            NSLog(@"Invalid search hex string: %@", searchHex);
        }

        [fileHandle closeFile];
    } else {
        NSLog(@"Failed to open file at path: %@", filePath);
    }

    return [offsets copy];
}


/**
 * hook机器码匹配通杀函数
 * @param hookFile 库名称
 * @param intelMachineCode intel机器码
 * @param arm64MachineCode arm机器码
 * @param matchCount 匹配数量 建议为1
 */
NSMutableDictionary*  hookPtrByMatchMachineCode(const char* hookFile,NSString* intelMachineCode,NSString* arm64MachineCode,int matchCount){
    //hook通杀开始
    intptr_t fileOffset = getCurrentArchFileOffset(hookFile);
    //当前需要检查的架构
    NSString *patchImage = [NSString stringWithUTF8String:hookFile];

    NSMutableDictionary *json = [NSMutableDictionary dictionaryWithDictionary:@{
        @"arm": @"",
        @"x86": @""
    }];

    NSArray<NSNumber *> *destinationFunction = findOffsetsForWildcardHexInFile(patchImage, intelMachineCode, matchCount);
    if (destinationFunction.count > 0) {
        for (NSNumber *destination in destinationFunction) {
            NSLog(@"==== Intel 通用Hook地址 %llx", destination.longLongValue);
            json[@"x86"] = [NSString stringWithFormat:@"%llx", destination.longLongValue];
        }
    }
    
    destinationFunction = findOffsetsForWildcardHexInFile(patchImage, arm64MachineCode, matchCount);
   
    if (destinationFunction.count > 0) {
        for (NSNumber *destination in destinationFunction) {
            NSLog(@"==== ARM 通用Hook地址 %llx", destination.longLongValue);
            json[@"arm"] = [NSString stringWithFormat:@"%llx", destination.longLongValue];
        }
    } else {
        NSLog(@"==== 没有匹配到数据");
    }
    return json;
}

@end
