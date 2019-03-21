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
    openPanel.title = @"选择导出目录";
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
    }
    else {
        [[NSUserDefaults standardUserDefaults] setObject:platform forKey:selectedPlatformKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [[NSUserDefaults standardUserDefaults] setObject:exportPath forKey:exportedPathKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        [self generateImagesForPlatform:platform fromOriginalImage:image];
    }
}


#pragma mark - Private functions

- (void)generateImagesForPlatform:(NSString *)platform fromOriginalImage:(NSImage *)originalImage {
    
    NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"QiConfiguration" ofType:@"plist"];
    NSDictionary *configuration = [NSDictionary dictionaryWithContentsOfFile:plistPath];
    NSArray<NSDictionary *> *items = configuration[platform];
    
    NSString *directoryPath = [[_pathField.stringValue stringByAppendingPathComponent:platform] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [[NSFileManager defaultManager] createDirectoryAtPath:directoryPath withIntermediateDirectories:YES attributes:nil error:nil];
    
    if ([platform containsString:@"AppIcons"]) {
        [self generateAppIconsWithConfigurations:items fromOriginalImage:originalImage toDirectoryPath:directoryPath];
    }
    else if ([platform containsString:@"LaunchImages"]) {
        [self generateLaunchImagesWithConfigurations:items fromOriginalImage:originalImage toDirectoryPath:directoryPath];
    }
}

- (void)generateAppIconsWithConfigurations:(NSArray<NSDictionary *> *)configurations fromOriginalImage:(NSImage *)originalImage toDirectoryPath:(NSString *)directoryPath {
    
    for (NSDictionary *configuration in configurations) {
        NSImage *appIcon = [self generateAppIconWithImage:originalImage forSize:NSSizeFromString(configuration[@"size"])];
        NSString *filePath = [NSString stringWithFormat:@"%@/%@.png", directoryPath, configuration[@"name"]];
        [self exportImage:appIcon toPath:filePath];
    }
    [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:directoryPath isDirectory:YES]];
}

- (void)generateLaunchImagesWithConfigurations:(NSArray<NSDictionary *> *)configurations fromOriginalImage:(NSImage *)originalImage toDirectoryPath:(NSString *)directoryPath {
    
    for (NSDictionary *configuration in configurations) {
        NSImage *launchImage = [self generateLaunchImageWithImage:originalImage forSize: NSSizeFromString(configuration[@"size"])];
        
        NSString *filePath = [NSString stringWithFormat:@"%@/%@.png", directoryPath, configuration[@"name"]];
        [self exportImage:launchImage toPath:filePath];
    }
    [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:directoryPath isDirectory:YES]];
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
    
    // 计算目标小图去贴合源大图所需要放大的比例
    CGFloat wFactor = fromImage.size.width / toSize.width;
    CGFloat hFactor = fromImage.size.height / toSize.height;
    CGFloat toFactor = fminf(wFactor, hFactor);
    
    // 根据所需放大的比例，计算与目标小图同比例的源大图的剪切Rect
    CGFloat scaledWidth = toSize.width * toFactor;
    CGFloat scaledHeight = toSize.height * toFactor;
    CGFloat scaledOriginX = (fromImage.size.width - scaledWidth) / 2;
    CGFloat scaledOriginY = (fromImage.size.height - scaledHeight) / 2;
    NSRect fromRect = NSMakeRect(scaledOriginX, scaledOriginY, scaledWidth, scaledHeight);
    
    // 生成即将绘制的目标图和目标Rect
    NSRect toRect = NSMakeRect(.0, .0, toSize.width, toSize.height);
    toRect = [[NSScreen mainScreen] convertRectFromBacking:toRect];
    NSImage *toImage = [[NSImage alloc] initWithSize:toRect.size];
    
    // 绘制
    [toImage lockFocus];
    [fromImage drawInRect:toRect fromRect:fromRect operation:NSCompositeCopy fraction:1.0];
    [toImage unlockFocus];
    
    return toImage;
}

- (void)exportImage:(NSImage *)image toPath:(NSString *)path {
    
    NSData *imageData = image.TIFFRepresentation;
    NSData *exportData = [[NSBitmapImageRep imageRepWithData:imageData] representationUsingType:NSPNGFileType properties:@{}];
    
    [exportData writeToFile:path atomically:YES];
}

@end
