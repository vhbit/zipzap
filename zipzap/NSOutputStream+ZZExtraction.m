//
// Created by vhbit on 3/6/13.
//

#import "NSOutputStream+ZZExtraction.h"


@implementation NSOutputStream (ZZExtraction)


const NSUInteger kDefaultBufSize = 1024 * 256;

- (void)ZZ_copyFromStream:(NSInputStream *)stream
{
    [self ZZ_copyFromStream:stream bufferSize:kDefaultBufSize];
}

- (void)ZZ_copyFromStream:(NSInputStream *)stream bufferSize:(NSUInteger)bufferSize
{
    [self ZZ_copyFromStream:stream bufferSize:bufferSize dataProcessor:nil];
}

- (void)ZZ_copyFromStream:(NSInputStream *)stream dataProcessor:(ZZDataProcessor)dataProcessor
{
    [self ZZ_copyFromStream:stream bufferSize:kDefaultBufSize dataProcessor:dataProcessor];
}

- (void)ZZ_copyFromStream:(NSInputStream *)stream bufferSize:(NSUInteger)bufferSize dataProcessor:(ZZDataProcessor)dataProcessor
{
    uint8_t *buf = malloc(bufferSize);
    NSInteger bytesRead = 0;

    do
    {
        bytesRead = [stream read:buf maxLength:bufferSize];
        if (bytesRead > 0)
        {
            [self write:buf maxLength:(NSUInteger) bytesRead];
            if (dataProcessor)
                dataProcessor(buf, (NSUInteger) bytesRead);
        }
    }
    while (bytesRead > 0);

    free(buf);
}

@end