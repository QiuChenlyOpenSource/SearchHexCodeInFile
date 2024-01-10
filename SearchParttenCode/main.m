//
//  main.m
//  SearchParttenCode
//
//  Created by qiuchenly on 2023/10/13.
//

#import <Foundation/Foundation.h>
#import "Utils.h"


int main(int argc, const char * argv[]) {
    @autoreleasepool {
        const char * target = argv[1];
        if (target == NULL){
            NSLog(@"请提供目标参数！");
            return -3;
        }
        
        NSString *executablePath = [[NSBundle mainBundle] executablePath];
        NSString *executableDirectory = [executablePath stringByDeletingLastPathComponent];
        executableDirectory = [executableDirectory stringByAppendingString:@"/"];

        NSLog(@"可执行文件所在的目录：%@", executableDirectory);
        
        /**
         文件内容格式示例
         {
           "surge": {
             "locate": "/Applications/Surge.app/Contents/Library/LaunchServices/com.nssurge.surge-mac.helper",
             "arm": "FF C3 02 D1 FA 67 06 A9 F8 5F 07 A9 F6 57 08 A9 F4 4F 09 A9 FD 7B 0A A9 FD 83 02 91 F3 03 00 AA BF 83 1B F8 19 01 00 B0 20 ?? 43 F9 62 12 40 F9 ?? 46 00 94 A2 23 01 D1 01 00 80 52 ?? 3F 00 94 C0 00 00 F0 00 E0 3C 91 E2 43 01 91 01 00 80 52 ?? ?? 00 94 A0 83 5B F8 E2 2B 40 F9 81 00 80 52 ?? ?? 00 94 F5 03 00 AA A0 83 5B F8 ?? 3E 00 94 E0 2B 40 F9 ?? 3E 00 94 C0 00 00 F0 00 60 3D 91 E2 43 01 91 01 00 80 52",
             "x86": "55 48 89 E5 41 57 41 56 41 55 41 54 53 48 83 EC 58 48 89 FB 4C 8D 7D C0 49 C7 07 00 00 00 00 48 8B 3D ?? ?? 01 00 48 8B 53 20 48 8B 35 ?? ?? 01 00 4C 8B 35 ?? ?? 01 00 41 FF D6 48 89 C7 31 F6 4C 89 FA E8 ?? ?? 01 00 48 8D 3D ?? ?? 01 00 4C 8D 65 C8 31 F6 4C 89 E2 E8 ?? ?? 01 00 49 8B 3F 49 8B 14 24 BE 04 00 00 00 E8 ?? ?? 01 00 89 45 BC 49 8B 3F E8 ?? ?? 01 00 49 8B 3C 24 E8 ?? ?? 01 00 48 8D 3D ?? ?? 01 00 31 F6 4C 89 E2 E8 ?? 2A 01 00",
             "out": "surge.sh",
             "replaceIntel": "{{intel}}",
             "replaceARM": "{{arm64}}"
           }
         }
         */
        NSString *filePath = [executableDirectory stringByAppendingString: @"Patch.json"];

        // 读取文件内容
        NSError *error;
        NSString *jsonString = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];

        if (error) {
            NSLog(@"读取文件出错：%@", error);
            return -2;
        }

        // 解析 JSON 数据
        NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
        id jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];

        if (error) {
            NSLog(@"解析 JSON 数据出错：%@", error);
            return -1;
        }

        NSDictionary *jsonDict = (NSDictionary *)jsonObject;
        
        NSDictionary *info = jsonDict[[NSString stringWithUTF8String:target]];
        
        if(info == nil) {
            NSLog(@"没有找到记录对应的数据！ %s", target);
            return -4;
        }
        
        NSArray *locateArray = (NSArray *)info[@"locate"];

        for (NSString *item in locateArray) {
            NSMutableDictionary* res = hookPtrByMatchMachineCode([item UTF8String],
                                      info[@"x86"],
                                      info[@"arm"],
                                      1);
            
            NSString *targetFile = [executableDirectory stringByAppendingString:info[@"out"]];
            NSError *fileError;
            NSString *fileContent = [NSString stringWithContentsOfFile:targetFile encoding:NSUTF8StringEncoding error:&error];
            if (fileContent) {
                NSString *keyIntel = info[@"replaceIntel"];
                NSString *keyARM = info[@"replaceARM"];
                
                NSString *modifiedContent = [fileContent stringByReplacingOccurrencesOfString:keyIntel withString:res[@"x86"]];
                
                modifiedContent = [modifiedContent stringByReplacingOccurrencesOfString:keyARM withString:res[@"arm"]];
                
                BOOL success = [modifiedContent writeToFile:targetFile atomically:YES encoding:NSUTF8StringEncoding error:&fileError];
                if (success) {
                    NSLog(@"成功更新了目标文件中的内容.");
                } else {
                    NSLog(@"更新参数失败！ %@", error);
                }
            } else {
                NSLog(@"无法读取待更新参数的文件错误: %@", error);
            }
            
            NSString* needFixPlist = info[@"fixPlist"];
            if (needFixPlist!=nil) {
                NSLog(@"准备修复Plist信息...\n文件: %@",item);
                
                NSData *fileData = [NSData dataWithContentsOfFile:item];
                if (fileData == nil) {
                    NSLog(@"无法读取文件");
                    return -5;
                }

                // 在这里处理二进制数据
                // 您可以使用NSData的方法来访问和操作二进制数据
                // 例如，[fileData bytes]返回指向二进制数据的指针，[fileData length]返回数据的长度
                const void *bytes = [fileData bytes];
                NSMutableData *mutableFileData = [NSMutableData dataWithData:fileData];
                const long len = [fileData length];
                
                NSLog(@"大小: %li字节",len);
                
                NSArray<NSNumber *> *destinationInx = findOffsetsForWildcardHexInFile(item, @"3C 6B 65 79 3E 53 4D 41 75 74 68 6F 72 69 7A 65 64 43 6C 69 65 6E 74 73 3C 2F 6B 65 79 3E", @"");
                
                for (NSNumber* inx in destinationInx){
                    int start = [inx intValue];
                    NSLog(@"开始位置: %i",[inx intValue]);
                    
                    const void *startByte = bytes + start;
                    const void *searchResult = memmem(startByte, len - start, "\x3C\x2F\x61\x72\x72\x61\x79\x3E", 8);
                    
                    if (searchResult != NULL) {
                        NSUInteger endIndex = searchResult - bytes;
                        NSUInteger length = endIndex - start + 8;
                        
                        NSData *subData = [NSData dataWithBytes:startByte length:length];
                        
                        NSString *stringData = [[NSString alloc] initWithData:subData encoding:NSUTF8StringEncoding];
                        
#ifdef DEBUG
                        
                        NSLog(@"%@", stringData);
                        
#endif
                        // 使用正则表达式提取特定部分
                        NSError *error = nil;
                        
                        //<string>anchor apple generic and identifier "com.proxyman.NSProxy" and
                        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"<string>.*?identifier \"(.*?)\"" options:0 error:&error];
                        if (error) {
                            NSLog(@"Regex error: %@", error.localizedDescription);
                        }
                        
                        NSArray<NSTextCheckingResult *> *matches = [regex matchesInString:stringData options:0 range:NSMakeRange(0, stringData.length)];
                        
                        
                        if([matches count] <=0){
                            NSLog(@"此区域已经被修改,跳过。");
                            break;
                        }
                        
                        NSMutableString *reformattedString = [NSMutableString string];
                        [reformattedString appendString:@"<key>SMAuthorizedClients</key>\n<array>\n"];

                        for (NSTextCheckingResult *match in matches) {
                            NSRange matchRange = [match rangeAtIndex:1];
                            NSString *stringValue = [stringData substringWithRange:matchRange];
                            [reformattedString appendFormat:@"\t<string>identifier \"%@\"</string>\n", stringValue];
                        }

                        [reformattedString appendString:@"</array>"];
#ifdef DEBUG
                        NSLog(@"%@", reformattedString);
#endif
                        NSData* finalBytes = [reformattedString dataUsingEncoding:NSUTF8StringEncoding];
                        
                        // 获取reformattedData的长度
                        NSUInteger reformattedLength = [finalBytes length];

                        // 计算剩余空间需要填充的字节数
                        NSUInteger remainingLength = length - reformattedLength;

                        // 替换原始部分
                        [mutableFileData replaceBytesInRange:NSMakeRange(start, reformattedLength) withBytes:[finalBytes bytes] length:reformattedLength];
                        
                        // 填充剩余空间
                        if (remainingLength > 0) {
                            unsigned char paddingBytes[remainingLength];
                            memset(paddingBytes, 0x0A, remainingLength);
                            [mutableFileData replaceBytesInRange:NSMakeRange(start + reformattedLength, remainingLength) withBytes:paddingBytes length:remainingLength];
                        }
                    } else {
                        NSLog(@"未找到指定字节序列");
                    }
                }
                // 将修改后的数据写回文件
                if (![mutableFileData writeToFile:item atomically:YES]) {
                    NSLog(@"写入文件失败");
                    return -7;
                }
                NSLog(@"文件修复完成.");
            }
        }
//        CleanMyMacX();
    }
    return 0;
}
