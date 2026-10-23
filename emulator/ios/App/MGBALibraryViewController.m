// SPDX-License-Identifier: MPL-2.0
#import "MGBALibraryViewController.h"
#import "MGBALibrary.h"
#import "MGBAPlayerViewController.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
@interface MGBALibraryViewController () <UIDocumentPickerDelegate>
@end
@implementation MGBALibraryViewController {
    MGBALibrary *_library;
    NSArray<MGBAGame *> *_games;
    BOOL _importing;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    _library = [MGBALibrary new];
    self.title = @"mGBA";
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(chooseROM)];
    self.navigationItem.rightBarButtonItem.accessibilityLabel = @"Importer des jeux";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"info.circle"] style:UIBarButtonItemStylePlain target:self action:@selector(showAbout)];
    self.navigationItem.leftBarButtonItem.accessibilityLabel = @"À propos et licences";
    self.tableView.rowHeight = 78;
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    [self reloadLibrary];
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self reloadLibrary]; }
- (void)reloadLibrary {
    _games = [_library games];
    [self.tableView reloadData];
    if (!_games.count) {
        UILabel *empty = [UILabel new];
        empty.text = @"Votre console de poche\n\nTouchez + pour importer vos jeux\nGBA, Game Boy et Game Boy Color.\n\nAucun jeu commercial n’est inclus.";
        empty.textAlignment = NSTextAlignmentCenter;
        empty.numberOfLines = 0;
        empty.textColor = UIColor.secondaryLabelColor;
        empty.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        empty.adjustsFontForContentSizeCategory = YES;
        self.tableView.backgroundView = empty;
    } else self.tableView.backgroundView = nil;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return _games.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"game"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"game"];
    MGBAGame *game = _games[indexPath.row];
    UIListContentConfiguration *content = cell.defaultContentConfiguration;
    content.text = game.title;
    NSString *console = [game.romURL.pathExtension isEqual:@"gba"] ? @"Game Boy Advance" : [game.romURL.pathExtension isEqual:@"gbc"] ? @"Game Boy Color" : @"Game Boy";
    BOOL resume = [NSFileManager.defaultManager fileExistsAtPath:[game.directory URLByAppendingPathComponent:@"resume.ss0"].path];
    content.secondaryText = [console stringByAppendingString:resume ? @" · Reprendre" : @" · Jouer"];
    content.image = [UIImage systemImageNamed:@"gamecontroller.fill"];
    content.imageProperties.tintColor = [UIColor colorWithRed:0.2 green:0.65 blue:0.48 alpha:1];
    cell.contentConfiguration = content;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (_importing || self.presentedViewController) return;
    MGBAPlayerViewController *player = [[MGBAPlayerViewController alloc] initWithGame:_games[indexPath.row]];
    [self presentViewController:player animated:YES completion:nil];
}
- (void)chooseROM {
    if (_importing) return;
    // Data also permits files whose provider does not know the declared ROM UTI.
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeData] asCopy:YES];
    picker.allowsMultipleSelection = YES;
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    [controller dismissViewControllerAnimated:YES completion:^{ [self importURLs:urls]; }];
}
- (void)importURLs:(NSArray<NSURL *> *)urls {
    [self loadViewIfNeeded];
    if (_importing || !urls.count) return;
    _importing = YES;
    self.navigationItem.rightBarButtonItem.enabled = NO;
    self.title = @"Importation…";
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSMutableArray<NSString *> *errors = [NSMutableArray array];
        for (NSURL *url in urls) {
            NSError *error = nil;
            if (![self->_library importROM:url error:&error]) [errors addObject:[NSString stringWithFormat:@"%@ : %@", url.lastPathComponent, error.localizedDescription ?: @"Import impossible."]];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_importing = NO;
            self.title = @"mGBA";
            self.navigationItem.rightBarButtonItem.enabled = YES;
            [self reloadLibrary];
            if (errors.count) {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Importation" message:[errors componentsJoinedByString:@"\n\n"] preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            }
        });
    });
}
- (void)showAbout {
    UIViewController *controller = [UIViewController new];
    controller.title = @"À propos";
    controller.view.backgroundColor = UIColor.systemBackgroundColor;
    UITextView *text = [UITextView new];
    text.translatesAutoresizingMaskIntoConstraints = NO;
    text.editable = NO;
    text.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    text.adjustsFontForContentSizeCategory = YES;
    text.textContainerInset = UIEdgeInsetsMake(20, 20, 30, 20);
    NSURL *license = [NSBundle.mainBundle URLForResource:@"Licenses" withExtension:@"txt"];
    NSString *licenses = [NSString stringWithContentsOfURL:license encoding:NSUTF8StringEncoding error:nil];
    text.text = [@"mGBA iOS — port indépendant\nMoteur mGBA 0.10.5, par Jeffrey Pfau et les contributeurs.\n\nGBA / GB / GBC · commandes tactiles et manettes · états et sauvegardes.\n\nVos fichiers restent dans l’application, accessibles depuis Fichiers > Sur mon iPhone/iPad > mGBA iOS. Aucun compte, publicité, téléchargement de jeux ou télémétrie.\n\nLes habillages peuvent être placés dans Skins/default : façade PNG avec transparence, boutons séparés et layout.json.\n\nCode source du moteur : https://github.com/mgba-emu/mgba/tree/0.10.5\nLe code du port est fourni dans le projet Xcode qui accompagne cette version.\n\n" stringByAppendingString:licenses ?: @""];
    [controller.view addSubview:text];
    [NSLayoutConstraint activateConstraints:@[[text.topAnchor constraintEqualToAnchor:controller.view.safeAreaLayoutGuide.topAnchor], [text.bottomAnchor constraintEqualToAnchor:controller.view.bottomAnchor], [text.leadingAnchor constraintEqualToAnchor:controller.view.leadingAnchor], [text.trailingAnchor constraintEqualToAnchor:controller.view.trailingAnchor]]];
    [self.navigationController pushViewController:controller animated:YES];
}
@end
