unit uMainForm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  {$IFDEF MSWINDOWS}
  Winapi.MMSystem,
  {$ENDIF}
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Objects,
  FMX.Ani, FMX.Media, FMX.Effects, System.Generics.Collections;

type
  TBulbState = (bsNormal, bsBroken, bsFalling);

  TChristmasBulb = class
  private
    FImage: TImage;
    FState: TBulbState;
    FVelocityY: Single;
    FOriginalY: Single;
    FOriginalRotation: Single;
    FOrnamentFile: string;
    FBrokenImage: TImage;
  public
    constructor Create(AOwner: TFmxObject; X, Y: Single; const OrnamentFile: string);
    destructor Destroy; override;
    procedure UpdateFall(DeltaTime: Single);
    procedure ShowBrokenOnFloor(FloorY: Single);
    property Image: TImage read FImage;
    property State: TBulbState read FState write FState;
    property VelocityY: Single read FVelocityY write FVelocityY;
    property OriginalY: Single read FOriginalY;
  end;


  TMainForm = class(TForm)
    Timer1: TTimer;
    MediaPlayer1: TMediaPlayer;
    FallTimer: TTimer;
    TreeImage: TImage;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure FallTimerTimer(Sender: TObject);
  private
    FBulbs: TObjectList<TChristmasBulb>;
    FLastTime: TDateTime;
    FGravity: Single;
    FFallingBulb: TChristmasBulb;
    FOrnamentFiles: TStringList;
    FBreakSoundFiles: TStringList;
    function GetResourcePath: string;
    procedure LoadTreeImage;
    procedure LoadOrnamentFiles;
    procedure LoadBreakSounds;
    procedure GetRandomTreePosition(out X, Y: Single);
    procedure CreateBulbs;
    procedure OnBulbClick(Sender: TObject);
    procedure PlayBreakSound;
  public
  end;

var
  MainForm: TMainForm;

implementation

{$R *.fmx}

uses
  System.Math, System.DateUtils, System.IOUtils;

const
  TREE_COLOR = $FF2D5016; // Dark green
  STAR_COLOR = $FFFFD700; // Gold
  GRAVITY = 500.0; // pixels per second squared

{ TChristmasBulb }

constructor TChristmasBulb.Create(AOwner: TFmxObject; X, Y: Single; const OrnamentFile: string);
begin
  FOrnamentFile := OrnamentFile;
  FBrokenImage := nil;

  FImage := TImage.Create(AOwner);
  if AOwner is TFmxObject then
    FImage.Parent := TFmxObject(AOwner);

  // Load ornament image
  if FileExists(OrnamentFile) then
    FImage.Bitmap.LoadFromFile(OrnamentFile);

  // Set size - scaled for phone screen (480x800)
  FImage.Width := 25;
  FImage.Height := 35;
  FImage.Position.X := X - FImage.Width / 2;  // Center on X position
  FImage.Position.Y := Y - FImage.Height / 2; // Center on Y position

  FState := bsNormal;
  FVelocityY := 0;
  FOriginalY := Y;
  FOriginalRotation := Random * 360; // Random starting rotation
  FImage.RotationAngle := FOriginalRotation;
end;

destructor TChristmasBulb.Destroy;
begin
  FImage.Free;
  if Assigned(FBrokenImage) then
    FBrokenImage.Free;
  inherited;
end;

procedure TChristmasBulb.UpdateFall(DeltaTime: Single);
begin
  if FState = bsFalling then
  begin
    FVelocityY := FVelocityY + (GRAVITY * DeltaTime);
    FImage.Position.Y := FImage.Position.Y + (FVelocityY * DeltaTime);

    // Add rotation as it falls
    FImage.RotationAngle := FImage.RotationAngle + (200 * DeltaTime);

    // Don't fade out - we want to see it fall
  end;
end;

procedure TChristmasBulb.ShowBrokenOnFloor(FloorY: Single);
var
  BrokenFile: string;
  Owner: TFmxObject;
  Form: TForm;
  ScaleY: Single;
  FloorAreaStart: Single;
begin
  // Hide the falling ornament
  FImage.Visible := False;

  // Look for broken version: ornament_red.png -> ornament_red_broken.png
  BrokenFile := StringReplace(FOrnamentFile, '.png', '_broken.png', [rfIgnoreCase]);

  if FileExists(BrokenFile) then
  begin
    Owner := TFmxObject(FImage.Parent);
    FBrokenImage := TImage.Create(Owner);
    FBrokenImage.Parent := Owner;

    // Load broken ornament image
    FBrokenImage.Bitmap.LoadFromFile(BrokenFile);

    // Get form reference to calculate floor area
    Form := nil;
    if Owner is TForm then
      Form := TForm(Owner);

    // Position in the floor area (between bottom of tree and bottom of screen)
    // Tree bottom is at Y=1390 in original image, scaled to screen
    if Assigned(Form) then
    begin
      ScaleY := Form.ClientHeight / 1575.0;
      FloorAreaStart := 1390 * ScaleY;  // Bottom of tree ornament area

      // Position broken ornament in floor area
      FBrokenImage.Width := 40;  // Size for broken pieces
      FBrokenImage.Height := 30;
      FBrokenImage.Position.X := FImage.Position.X + FImage.Width / 2 - FBrokenImage.Width / 2;
      // Random Y position in floor area
      FBrokenImage.Position.Y := FloorAreaStart + Random(Trunc(Form.ClientHeight - FloorAreaStart - FBrokenImage.Height));
    end
    else
    begin
      // Fallback if form not found
      FBrokenImage.Width := 40;
      FBrokenImage.Height := 30;
      FBrokenImage.Position.X := FImage.Position.X + FImage.Width / 2 - FBrokenImage.Width / 2;
      FBrokenImage.Position.Y := FloorY - FBrokenImage.Height;
    end;

    FBrokenImage.HitTest := False;
    FBrokenImage.BringToFront;
  end;
end;

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
begin
  // Set up form
  Self.Fill.Color := TAlphaColorRec.Midnightblue;

  FBulbs := TObjectList<TChristmasBulb>.Create(True);
  FOrnamentFiles := TStringList.Create;
  FBreakSoundFiles := TStringList.Create;
  FGravity := GRAVITY;
  FFallingBulb := nil;

  LoadTreeImage;
  LoadOrnamentFiles;
  LoadBreakSounds;
  CreateBulbs;

  FLastTime := Now;
  Timer1.Interval := 16; // ~60 FPS
  Timer1.Enabled := True;

  FallTimer.Interval := 100;
  FallTimer.Enabled := False;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FBulbs.Free;
  FOrnamentFiles.Free;
  FBreakSoundFiles.Free;
end;

function TMainForm.GetResourcePath: string;
begin
  {$IF DEFINED(MSWINDOWS)}
  // Windows: resources in same directory as executable
  Result := TPath.GetDirectoryName(ParamStr(0));
  {$ELSEIF DEFINED(ANDROID)}
  // Android: resources in assets/internal folder
  Result := TPath.GetDocumentsPath;
  {$ELSE}
    {$IF DEFINED(MACOS) OR DEFINED(IOS)}
    // iOS/macOS: resources in documents
    Result := TPath.GetDocumentsPath;
    showmessage('ios/mac path: ' + result);
    {$ENDIF}
  {$ELSE}
  {$MESSAGE FATAL 'Platform Not Supported'}
  {$ENDIF}
end;

procedure TMainForm.LoadBreakSounds;
var
  SearchRec: TSearchRec;
  FullPath: string;
  SearchPattern: string;
  SearchPath: string;
begin
  // Platform-specific sound file formats
  {$IFDEF MSWINDOWS}
  SearchPattern := 'glass-break-*.wav';  // Windows uses WAV
  {$ELSEIF DEFINED(ANDROID)}
  SearchPattern := 'glass-break-*.mp3';  // Android uses MP3
  {$ELSEIF DEFINED(IOS) OR DEFINED(MACOS)}
  SearchPattern := 'glass-break-*.caf';  // iOS/macOS uses CAF
  {$ENDIF}

  // Find all glass-break sound files from platform-appropriate path
  SearchPath := TPath.Combine(GetResourcePath, SearchPattern);

  if FindFirst(SearchPath, faAnyFile, SearchRec) = 0 then
  begin
    repeat
      FullPath := TPath.Combine(GetResourcePath, SearchRec.Name);
      FBreakSoundFiles.Add(FullPath);
    until FindNext(SearchRec) <> 0;
    FindClose(SearchRec);
  end;
end;

procedure TMainForm.PlayBreakSound;
var
  RandomIndex: Integer;
  SoundFile: string;
begin
  if FBreakSoundFiles.Count > 0 then
  begin
    RandomIndex := Random(FBreakSoundFiles.Count);
    SoundFile := FBreakSoundFiles[RandomIndex];

    {$IFDEF MSWINDOWS}
    // On Windows, use sndPlaySound for faster playback
    sndPlaySound(PChar(SoundFile), SND_ASYNC or SND_NODEFAULT);
    {$ELSE}
    // On other platforms, use MediaPlayer1
    MediaPlayer1.Stop;
    MediaPlayer1.FileName := SoundFile;
    MediaPlayer1.Play;
    {$ENDIF}
  end;
end;

procedure TMainForm.LoadTreeImage;
var
  TreeFile: string;
begin
  // Load the Christmas tree image from platform-appropriate path
  TreeFile := TPath.Combine(GetResourcePath, 'ChristmasTree.png');

  if FileExists(TreeFile) then
  begin
    TreeImage.Bitmap.LoadFromFile(TreeFile);
    TreeImage.SendToBack; // Make sure image is behind ornaments and lights
  end
  else
    ShowMessage('ChristmasTree.png not found in: ' + GetResourcePath);
end;

procedure TMainForm.LoadOrnamentFiles;
var
  SearchRec: TSearchRec;
  SearchPath: string;
  FullPath: string;
begin
  // Find all ornament PNG files (excluding broken versions)
  SearchPath := TPath.Combine(GetResourcePath, 'ornament*.png');

  if FindFirst(SearchPath, faAnyFile, SearchRec) = 0 then
  begin
    repeat
      // Only add non-broken ornament files
      if Pos('_broken', LowerCase(SearchRec.Name)) = 0 then
      begin
        FullPath := TPath.Combine(GetResourcePath, SearchRec.Name);
        FOrnamentFiles.Add(FullPath);
      end;
    until FindNext(SearchRec) <> 0;
    FindClose(SearchRec);
  end;

  if FOrnamentFiles.Count = 0 then
    ShowMessage('No ornament PNG files found in: ' + GetResourcePath);
end;

procedure TMainForm.GetRandomTreePosition(out X, Y: Single);
var
  TreeTop: Single;
  TreeBottom: Single;
  TreeLeft: Single;
  TreeRight: Single;
  TreeTopX: Single;
  YFromTop: Single;
  HalfWidth: Single;
  ScaleX, ScaleY: Single;
  OrigX, OrigY: Single;
  RandomValue: Single;
begin
  // Tree dimensions in edited image (cut 150 top, 100 bottom, scaled 50%):
  // New image size: 1050 x 1575
  // Top (star): X=514, Y=28
  // Bottom left: X=80, Y=1540
  // Bottom right: X=930, Y=1540
  // Skip top 150 pixels (scaled from 300) for star area
  // Move bottom up 150 pixels to avoid floor area

  TreeTopX := 514;
  TreeTop := 28 + 150;  // Skip 150 pixels for star
  TreeBottom := 1540 - 150;  // Move bottom up 150 pixels
  TreeLeft := 80;
  TreeRight := 930;

  // Pick random Y within tree height, weighted heavily towards bottom
  // Use power function inverted to skew distribution towards bottom (larger Y values)
  RandomValue := Random;
  RandomValue := 1 - RandomValue; // Invert
  RandomValue := RandomValue * RandomValue; // Square to weight towards 0
  RandomValue := 1 - RandomValue; // Invert back - now weighted towards 1.0 (bottom)
  OrigY := TreeTop + RandomValue * (TreeBottom - TreeTop);

  // Calculate how wide the tree is at this Y position
  // Tree is a triangle, so width increases linearly from top to bottom
  YFromTop := OrigY - 28; // Distance from actual top (not adjusted top)
  HalfWidth := (YFromTop / (TreeBottom - 28)) * ((TreeRight - TreeLeft) / 2);

  // Random X within the triangle at this Y
  OrigX := TreeTopX + (Random * 2 - 1) * HalfWidth;

  // Scale to current form size (480x800 from edited 1050x1575)
  ScaleX := Self.ClientWidth / 1050.0;
  ScaleY := Self.ClientHeight / 1575.0;

  X := OrigX * ScaleX;
  Y := OrigY * ScaleY;
end;

procedure TMainForm.CreateBulbs;
var
  i: Integer;
  X, Y: Single;
  Bulb: TChristmasBulb;
  OrnamentFile: string;
begin
  if FOrnamentFiles.Count = 0 then
    Exit; // No ornament files found

  // Add ornamental bulbs scattered across the tree
  for i := 0 to 29 do  // Increased to 30 ornaments
  begin
    // Get random position within tree triangle
    GetRandomTreePosition(X, Y);

    // Pick random ornament file
    OrnamentFile := FOrnamentFiles[Random(FOrnamentFiles.Count)];

    Bulb := TChristmasBulb.Create(Self, X, Y, OrnamentFile);
    Bulb.Image.OnClick := OnBulbClick;
    Bulb.Image.HitTest := True;
    Bulb.Image.Cursor := crHandPoint;
    Bulb.Image.BringToFront; // Make sure bulbs appear on top of tree image
    FBulbs.Add(Bulb);
  end;
end;

procedure TMainForm.OnBulbClick(Sender: TObject);
var
  ClickedImage: TImage;
  Bulb: TChristmasBulb;
begin
  if not (Sender is TImage) then Exit;

  ClickedImage := TImage(Sender);

  // Find the bulb that owns this image
  for Bulb in FBulbs do
  begin
    if Bulb.Image = ClickedImage then
    begin
      if Bulb.State = bsNormal then
      begin
        Bulb.State := bsBroken;

        // Store reference and start timer for delayed fall
        FFallingBulb := Bulb;
        FallTimer.Enabled := True;
      end;
      Break;
    end;
  end;
end;

procedure TMainForm.FallTimerTimer(Sender: TObject);
begin
  FallTimer.Enabled := False;
  if Assigned(FFallingBulb) then
  begin
    FFallingBulb.State := bsFalling;
    FFallingBulb.VelocityY := 0;
    FFallingBulb := nil;
  end;
end;

procedure TMainForm.Timer1Timer(Sender: TObject);
var
  CurrentTime: TDateTime;
  DeltaTime: Single;
  Bulb: TChristmasBulb;
begin
  CurrentTime := Now;
  DeltaTime := MilliSecondsBetween(CurrentTime, FLastTime) / 1000.0;
  FLastTime := CurrentTime;

  // Limit delta time to prevent huge jumps
  if DeltaTime > 0.1 then
    DeltaTime := 0.1;

  // Update falling bulbs
  for Bulb in FBulbs do
  begin
    if Bulb.State = bsFalling then
    begin
      Bulb.UpdateFall(DeltaTime);

      // Check if bulb hit the bottom of the tree area (Y=1390 in original, scaled)
      var TreeBottomY := 1390 * (Self.ClientHeight / 1575.0);
      if Bulb.Image.Position.Y + Bulb.Image.Height >= TreeBottomY then
      begin
        PlayBreakSound; // Play sound when it hits the floor
        Bulb.ShowBrokenOnFloor(TreeBottomY);
        Bulb.State := bsNormal; // Done falling, now broken on floor
      end;
    end;
  end;
end;

end.
