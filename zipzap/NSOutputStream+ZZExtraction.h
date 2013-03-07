//
// Created by vhbit on 3/6/13.
//

#import <Foundation/Foundation.h>

typedef void (^ZZDataProcessor)(uint8_t *buffer, NSUInteger length);

@interface NSOutputStream (ZZExtraction)
- (void)ZZ_copyFromStream:(NSInputStream *)stream;
- (void)ZZ_copyFromStream:(NSInputStream *)stream bufferSize:(NSUInteger)bufferSize;
- (void)ZZ_copyFromStream:(NSInputStream *)stream dataProcessor:(ZZDataProcessor)dataProcessor;
- (void)ZZ_copyFromStream:(NSInputStream *)stream bufferSize:(NSUInteger)bufferSize dataProcessor:(ZZDataProcessor)dataProcessor;
@end