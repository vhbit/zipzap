//
//  ZZExtractionTests.m
//  zipzap
//
//  Created by Valerii Hiora on 03/07/13.
//  Copyright (c) 2013 __MyCompanyName__. All rights reserved.
//

#import "ZZExtractionTests.h"

#import "ZZArchive+ZZExtraction.h"

@implementation ZZExtractionTests

- (void)testPreservingPaths
{
    ZZFileNameProcessor processor = [ZZArchive preservingFileNameProcessor:@"/test/"];
    STAssertEqualObjects(processor(@"f1"), @"/test/f1", @"No hierarchy");
    STAssertEqualObjects(processor(@"d1/f1"), @"/test/d1/f1", @"Relative path");
    STAssertEqualObjects(processor(@"/d1/f1"), @"/test/d1/f1", @"Absolute path");
}

- (void)testNonPreservingPaths
{
    ZZFileNameProcessor processor = [ZZArchive nonPreservingFileNameProcessor:@"/test/"];
    STAssertEqualObjects(processor(@"f1"), @"/test/f1", @"No hierarchy");
    STAssertEqualObjects(processor(@"d1/f1"), @"/test/f1", @"Relative path");
    STAssertEqualObjects(processor(@"/d1/f1"), @"/test/f1", @"Absolute path");
}

@end
