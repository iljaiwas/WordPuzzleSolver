//
//  SearchHit.h
//  WordPuzzleSolver
//
//  Created by ilja on 10.05.2021.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SearchHit : NSObject

@property NSString  *word;
@property NSInteger column;
@property NSInteger row;
@property NSInteger direction;

@end

NS_ASSUME_NONNULL_END
