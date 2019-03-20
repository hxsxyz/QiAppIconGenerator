//
//  ViewController.m
//  QiAppIconGenerator
//
//  Created by huangxianshuai on 2019/3/19.
//  Copyright © 2019年 QiShare. All rights reserved.
//

#import "ViewController.h"

static NSString * const selectedPlatformKey = @"selectedPlatform";
static NSString * const exportedPathKey = @"exportedPath";

@interface ViewController ()

@property (weak) IBOutlet NSImageView *imageView;
@property (weak) IBOutlet NSComboBox *platformBox;
@property (weak) IBOutlet NSButton *pathButton;
@property (weak) IBOutlet NSTextField *pathField;
@property (weak) IBOutlet NSButton *exportButton;

@end

@implementation ViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    NSString *selectedPlatform = [[NSUserDefaults standardUserDefaults] objectForKey:selectedPlatformKey];
    [_platformBox selectItemWithObjectValue:selectedPlatform];
    
    NSString *lastExportedPath = [[NSUserDefaults standardUserDefaults] objectForKey:exportedPathKey];
    _pathField.stringValue = lastExportedPath ?: NSHomeDirectory();
}


#pragma mark - Action functions

- (IBAction)pathButtonClicked:(NSButton *)sender {
    
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    openPanel.canChooseDirectories = YES;
    openPanel.canChooseFiles = NO;
    openPanel.title = @"选择目录";
    [openPanel beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {
            self.pathField.stringValue = openPanel.URL.path;
        }
    }];
}

- (IBAction)exportButtonClicked:(NSButton *)sender {
    
    NSImage *image = _imageView.image;
    NSString *platform = _platformBox.selectedCell.title;
    NSString *exportPath = _pathField.stringValue;
    
    if (!image || !platform || !exportPath) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"请先选择源图片、平台和导出路径";
        alert.alertStyle = NSAlertStyleWarning;
        [alert addButtonWithTitle:@"确认"];
        [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {}];
        return;
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:platform forKey:selectedPlatformKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSUserDefaults standardUserDefaults] setObject:exportPath forKey:exportedPathKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self generateImagesForPlatform:platform fromOriginalImage:image];
}


#pragma mark - Private functions

- (void)generateImagesForPlatform:(NSString *)platform fromOriginalImage:(NSImage *)originalImage {
    
    NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"QiConfiguration" ofType:@"plist"];
    NSDictionary *configuration = [NSDictionary dictionaryWithContentsOfFile:plistPath];
    NSArray<NSDictionary *> *items = configuration[platform];
    
    if ([platform containsString:@"AppIcons"]) {
        NSString *directoryPath = [[_pathField.stringValue stringByAppendingPathComponent:@"AppIcons"] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        [[NSFileManager defaultManager] createDirectoryAtPath:directoryPath withIntermediateDirectories:YES attributes:nil error:nil];
        [self generateAppIconsWithConfigurations:items fromOriginalImage:originalImage toDirectoryPath:directoryPath];
    }
    else if ([platform containsString:@"LaunchImages"]) {
        NSString *directoryPath = [[_pathField.stringValue stringByAppendingPathComponent:@"LaunchImages"] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        [[NSFileManager defaultManager] createDirectoryAtPath:directoryPath withIntermediateDirectories:YES attributes:nil error:nil];
        [self generateLaunchImagesWithConfigurations:items fromOriginalImage:originalImage toDirectoryPath:directoryPath];
    }
}

- (void)generateAppIconsWithConfigurations:(NSArray<NSDictionary *> *)configurations fromOriginalImage:(NSImage *)originalImage toDirectoryPath:(NSString *)directoryPath {
    
    for (NSDictionary *configuration in configurations) {
        NSImage *appIcon = [self generateAppIconWithImage:originalImage forSize:NSSizeFromString(configuration[@"size"])];
        NSString *filePath = [NSString stringWithFormat:@"%@/%@.png", directoryPath, configuration[@"name"]];
        [self exportImage:appIcon toPath:filePath];
    }
    [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:_pathField.stringValue isDirectory:YES]];
}

- (void)generateLaunchImagesWithConfigurations:(NSArray<NSDictionary *> *)configurations fromOriginalImage:(NSImage *)originalImage toDirectoryPath:(NSString *)directoryPath {
    
    for (NSDictionary *configuration in configurations) {
        NSImage *launchImage = [self generateLaunchImageWithImage:originalImage forSize: NSSizeFromString(configuration[@"size"])];
        
        NSString *filePath = [NSString stringWithFormat:@"%@/%@.png", directoryPath, configuration[@"name"]];
        [self exportImage:launchImage toPath:filePath];
    }
    [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:_pathField.stringValue isDirectory:YES]];
}

- (NSImage *)generateAppIconWithImage:(NSImage *)fromImage forSize:(CGSize)toSize  {
    
    NSRect toFrame = NSMakeRect(.0, .0, toSize.width, toSize.height);
    toFrame = [[NSScreen mainScreen] convertRectFromBacking:toFrame];
    
    NSImageRep *imageRep = [fromImage bestRepresentationForRect:toFrame context:nil hints:nil];
    NSImage *toImage = [[NSImage alloc] initWithSize:toFrame.size];
    
    [toImage lockFocus];
    [imageRep drawInRect:toFrame];
    [toImage unlockFocus];
    
    return toImage;
}

- (NSImage *)generateLaunchImageWithImage:(NSImage *)fromImage forSize:(CGSize)toSize {
    
    CGFloat screenScale = [NSScreen mainScreen].backingScaleFactor;
    
    CGFloat fromWidth = fromImage.size.width / screenScale;
    CGFloat fromHeight = fromImage.size.height / screenScale;
    CGFloat toWidth = toSize.width / screenScale;
    CGFloat toHeight = toSize.height / screenScale;
    
    CGFloat widthFactor = toWidth / fromWidth;
    CGFloat heightFactor = toHeight / fromHeight;
    CGFloat scaleFactor = (widthFactor > heightFactor)? widthFactor: heightFactor;
    
    CGFloat readHeight = toHeight / scaleFactor;
    CGFloat readWidth = toWidth / scaleFactor;
    CGPoint readPoint = CGPointMake(widthFactor > heightFactor? .0: (fromWidth - readWidth) * 0.5, widthFactor < heightFactor ? .0: (fromHeight - readHeight) * 0.5);
    
    toSize = CGSizeMake(toWidth, toHeight);
    NSImage *toImage = [[NSImage alloc] initWithSize:toSize];
    CGRect thumbnailRect = {{0.0, 0.0}, toSize};
    NSRect imageRect = {readPoint, {readWidth, readHeight}};
    
    [toImage lockFocus];
    [fromImage drawInRect:thumbnailRect fromRect:imageRect operation:NSCompositeCopy fraction:1.0];
    [toImage unlockFocus];
    
    return toImage;
}

- (void)exportImage:(NSImage *)image toPath:(NSString *)path {
    
    NSData *imageData = image.TIFFRepresentation;
    NSData *exportData = [[NSBitmapImageRep imageRepWithData:imageData] representationUsingType:NSPNGFileType properties:@{}];
    
    [exportData writeToFile:path atomically:YES];
}

@end
