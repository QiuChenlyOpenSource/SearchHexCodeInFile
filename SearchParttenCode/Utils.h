//
//  Utils.h
//  SearchParttenCode
//
//  Created by qiuchenly on 2023/10/13.
//

#ifndef Utils_h
#define Utils_h


#endif /* Utils_h */

BOOL checkSelfInject(char *name);
BOOL checkAppVersion(char *checkVersion);
BOOL checkAppCFBundleVersion(char *checkVersion);
NSString* checkCPUSubType(void);
BOOL isX86(void);
intptr_t getAddress(intptr_t x86,intptr_t arm64);
void NOPAddress(intptr_t address);
void NOPAddressEx(intptr_t address, uint8_t *bytes, uint32_t len);
void initBaseEnv(void);
int ret0(void);
int ret1(void);
uint32_t getArchFileOffset(const uint32_t desiredCpuType, const char *baseName);
NSArray<NSNumber *> *findOffsetsForHexInFile(NSString *filePath, NSString *searchHex);
NSArray<NSDictionary *> *getArchitecturesInfoForFile(NSString *filePath);
uint32_t getCurrentArchFileOffset(const char* inxForArchImage);
    long getRealFileOffset2RAMOffsetA(long codeOffset, long fileOffset);
long getRealFileOffset2RAMOffset(long codeOffset, long fileOffset);
NSArray<NSNumber *> *findOffsetsForHexInCurrentFile(NSString *searchHex);
    NSArray<NSNumber *> *findOffsetsForWildcardHexInFile(NSString *filePath, NSString *searchHex, NSUInteger matchCount);

    void hookPtrByMatchMachineCodeA(char* hookFile,NSString* intelMachineCode,NSString* arm64MachineCode,int matchCount, void * newFunction);
    
    BOOL hookPtrPatchCodeByMatchMachineCode(
                                            uint32_t hookImageInx,
                                            NSString* _Nullable intelMachineCode,
                                            NSString* _Nullable arm64MachineCode,
                                            int patchByteStartCount,
                                            uint8_t* _Nullable patchCode,
                                            uint8_t patchCodeSize,
                                            int matchCount
                                            );
    BOOL hookPtrPatchCodeByMatchMachineCodeN(
                                             NSString* _Nullable intelMachineCode,
                                             NSString* _Nullable arm64MachineCode,
                                             int patchByteStartCount,
                                             uint8_t* _Nullable patchCode,
                                             uint8_t patchCodeSize
                                             );
    BOOL hookPtrPatchCodeByMatchMachineCodeC(
                                             NSString* _Nullable intelMachineCode,
                                             NSString* _Nullable arm64MachineCode,
                                             int patchByteStartCount,
                                             uint8_t* _Nullable patchCode,
                                             uint8_t patchCodeSize,
                                             int matchCount
                                             );
    BOOL hookPtrPatchCodeByMatchMachineCodeA(
                                             char* _Nullable hookImageName,
                                             NSString* _Nullable intelMachineCode,
                                             NSString* _Nullable arm64MachineCode,
                                             int patchByteStartCount,
                                             uint8_t* _Nullable patchCode,
                                             uint8_t patchCodeSize,
                                             int matchCount
                                             );


void hookPtrByMatchMachineCode(const char* hookFile,NSString* intelMachineCode,NSString* arm64MachineCode,int matchCount);


@interface Utils : NSObject

@end
