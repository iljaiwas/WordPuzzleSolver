//
//  AppDelegate.m
//  WordPuzzleSolver
//
//  Created by ilja on 08.05.2021.
//

#import "AppDelegate.h"
#import "SearchHit.h"

#define kNumberOfRows 11
#define kNumberOfColumns 11

#define kMinHitLength 3
#define kMaxHitLength 11

unichar data[kNumberOfRows][kNumberOfColumns] = {
    {'A', 'I', 'R', 'E', 'D', 'A', 'R', 'K', 'A', 'B', 'E' },
    {'D', 'P', 'T', 'L', 'E', 'S', 'S', 'E', 'F', 'E', 'R' },
    {'V', 'D', 'P', 'E', 'T', 'L', 'O', 'S', 'E', 'F', 'U' },
    {'I', 'M', 'D', 'O', 'C', 'T', 'O', 'R', 'S', 'O', 'T' },
    {'C', 'C', 'P', 'W', 'I', 'L', 'L', 'U', 'K', 'R', 'A' },
    {'E', 'M', 'E', 'I', 'G', 'N', 'G', 'E', 'I', 'E', 'R' },
    {'V', 'O', 'U', 'M', 'E', 'A', 'T', 'L', 'V', 'I', 'E' },
    {'S', 'S', 'A', 'T', 'R', 'V', 'M', 'M', 'E', 'N', 'P' },
    {'A', 'T', 'U', 'H', 'G', 'U', 'O', 'N', 'E', 'O', 'M' },
    {'Y', 'L', 'A', 'C', 'T', 'I', 'V', 'E', 'C', 'N', 'E' },
    {'M', 'Y', 'A', 'T', 'F', 'R', 'E', 'S', 'H', 'E', 'T' },
};

typedef struct SearchAnchor {
    NSInteger column;
    NSInteger row;
} SearchAnchor;

typedef NS_ENUM(NSUInteger, Direction) {
    DirectionLeft,
    DirectionRight,
    DirectionDown,
    DirectionUp,
    DirectionDownLeft,
    DirectionDownRight,
    DirectionUpLeft,
    DirectionUpRight
};

static void * const kDummyKVOContext = (void*)&kDummyKVOContext;

@interface AppDelegate ()

@property (strong) IBOutlet NSWindow *window;
@property (strong) NSMatrix *matrix;
@property (strong) NSMutableOrderedSet *wordSet;
@property (strong) NSMutableArray<SearchHit*> *hits;
@property (strong) IBOutlet NSArrayController *hitArrayController;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.matrix = [[NSMatrix alloc] initWithFrame:self.window.contentView.frame
                                             mode:NSListModeMatrix
                                        prototype:[[NSTextFieldCell alloc] init]
                                     numberOfRows:kNumberOfRows
                                  numberOfColumns:kNumberOfColumns];
    [self.window.contentView addSubview:self.matrix];
    [self loadMatrixContent];
    [self loadWordList];
    
    [self findHits];

    [self.hitArrayController addObserver:self forKeyPath:@"selection" options:0 context:kDummyKVOContext];
    [self.hitArrayController setContent:self.hits];
}

- (void) loadMatrixContent
{
    for (NSInteger row = 0; row < kNumberOfRows; row++) {
        for (NSInteger col = 0; col < kNumberOfColumns; col++) {
            NSTextFieldCell *cell = [self.matrix cellAtRow:row column:col];
            [cell setStringValue:[NSString stringWithFormat:@"%c", data[row][col]]];
        }
    }
}

- (void) loadWordList
{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"words_alpha" ofType:@"txt"];
    NSAssert(path, @"path to word list is nil");
    NSString *fileContent = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    NSArray *lines = [fileContent componentsSeparatedByString:@"\n"];

    self.wordSet = [[NSMutableOrderedSet alloc] init];
    for (NSString *line in lines) {
        if (line.length >= kMinHitLength && line.length <= kMaxHitLength) {
            [self.wordSet addObject:[line uppercaseString]];
        }
    }
}

- (void) findHits
{
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();

    self.hits = [NSMutableArray array];
    NSMutableString *word = [[NSMutableString alloc] initWithCapacity:kMaxHitLength];

    for (Direction dir = DirectionLeft; dir <= DirectionUpRight; dir++ ) {
        SearchAnchor anchor = {0,0};
        do {
            [word setString:@""];
            for (NSInteger wordLength = kMinHitLength; wordLength <= kMaxHitLength; wordLength++) {
                if (NO == [self getWordAtAnchor:&anchor length:wordLength direction:dir word:word]) {
                    break;
                }
                if ([self.wordSet containsObject:word]) {
                    SearchHit *hit = [[SearchHit alloc] init];
                    hit.word = word.lowercaseString;
                    hit.column = anchor.column;
                    hit.row = anchor.row;
                    hit.direction = dir;
                    [self.hits addObject:hit];
                }
            }
        } while ([self advanceAnchor:&anchor]);
    }
    [self.hits sortWithOptions:0 usingComparator:^NSComparisonResult(SearchHit*  _Nonnull obj1, SearchHit*  _Nonnull obj2) {
        return [[obj1 word] caseInsensitiveCompare:[obj2 word]];
    }];
    double duration = CFAbsoluteTimeGetCurrent() - start;
    NSLog(@"Took %.3fs, finding %ld hits", duration, self.hits.count);
}

- (bool) getWordAtAnchor:(SearchAnchor*) inAnchor length:(NSInteger) inLength direction:(Direction) inDirection word:(NSMutableString*) word;
{
    while (word.length < inLength) {
        NSInteger column = inAnchor->column + (word.length * [self columnDeltaForDirection:inDirection]);
        NSInteger row = inAnchor->row + (word.length * [self rowDeltaForDirection:inDirection]);

        if (column < 0 || column >= kNumberOfColumns) {
            return NO;
        }
        if (row < 0 || row >= kNumberOfRows) {
            return NO;
        }
        [word appendString:[NSString stringWithCharacters:&(data[row][column]) length:1]];
    }
    return YES;
}

- (BOOL) advanceAnchor:(SearchAnchor*) inAnchor {

    inAnchor->column++;
    if (inAnchor->column >= kNumberOfColumns) {
        inAnchor->column = 0;
        inAnchor->row++;
    }
    if (inAnchor->row >= kNumberOfRows) {
        return false;
    }
    return YES;
}

- (NSInteger) columnDeltaForDirection:(Direction) inDirection
{
    switch (inDirection) {
        case DirectionLeft:
        case DirectionDownLeft:
        case DirectionUpLeft:
        return 1;
        break;

        case DirectionRight:
        case DirectionDownRight:
        case DirectionUpRight:
            return -1;
            break;

        case DirectionDown:
        case DirectionUp:
            return 0;
            break;
    }
}

- (NSInteger) rowDeltaForDirection:(Direction) inDirection
{
    switch (inDirection) {

        case DirectionDownRight:
        case DirectionDownLeft:
        case DirectionDown:
            return 1;
            break;

        case DirectionUp:
        case DirectionUpLeft:
        case DirectionUpRight:
            return -1;
            break;

        case DirectionLeft:
        case DirectionRight:
            return 0;
            break;
    }
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == kDummyKVOContext){
        [self updateSelectionWithHit:[[self.hitArrayController selectedObjects] firstObject]];
    }
}

- (void) updateSelectionWithHit:(SearchHit*) inSearchHit
{
    for (NSInteger row = 0; row < kNumberOfRows; row++) {
        for (NSInteger col = 0; col < kNumberOfColumns; col++) {
            [[self.matrix cellAtRow:row column:col] setTextColor:[NSColor blackColor]];
        }
    }
    if (inSearchHit == nil) {
        return;
    }
    for (NSInteger i = 0; i < inSearchHit.word.length; i++) {
        NSInteger column = inSearchHit.column + (i * [self columnDeltaForDirection:inSearchHit.direction]);
        NSInteger row = inSearchHit.row + (i * [self rowDeltaForDirection:inSearchHit.direction]);

        [[self.matrix cellAtRow:row column:column] setTextColor:[NSColor greenColor]];
    }
}

@end
