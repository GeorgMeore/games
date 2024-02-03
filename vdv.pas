program VDV;
uses CRT, Math;

const
	ColorCount      = 12;
	DelayDuration   = 10;
	XScale          = 1;
	YScale          = 2.5;
	DefaultSize     = 10;
	DefaultVelocity = 0.1;

type
	ShapeKind = (CircleShape, DavidStarShape);
	Shape = record
		kind: ShapeKind;
		x, y, r: real;
		xmax, ymax: real;
		dx, dy: real;
		bumps: word;
	end;
	Rectangle = record
		x, y, w, h: integer;
	end;

var
	Colors: array [1..ColorCount] of word = (
		Blue, Green, Cyan,
		Red, Magenta, Brown,
		LightBlue, LightGreen, LightCyan,
		LightRed, LightMagenta, Yellow
	);

procedure GetKey(var code: integer);
var
	c: char;
begin
	c := ReadKey;
	if c = #0 then
		code := -ord(ReadKey)
	else
		code := ord(c)
end;

procedure HandleInput(var quit, pause: boolean);
var
	c: integer;
begin
	while KeyPressed do
	begin
		GetKey(c);
		if c = ord('q') then
			quit := true
		else if c = ord(' ') then
			pause := not pause
	end
end;

function Distance(x1, y1, x2, y2: real): real;
begin
	Distance := sqrt((x1 - x2)*(x1 - x2) + (y1 - y2)*(y1 - y2))
end;

function IsInsideCircle(x, y: real; var sh: Shape): boolean;
begin
	IsInsideCircle := Distance(x, y, sh.x, sh.y) <= sh.r
end;

function IsAboveLine(x, y, x1, y1, x2, y2: real): boolean;
var
	k1, k2: real;
begin
	if x = x1 then
		IsAboveLine := y >= y1
	else
	begin
		k1 := (y - y1)  / (x - x1);
		k2 := (y2 - y1) / (x2 - x1);
		if x > x1 then
			IsAboveLine := k1 >= k2
		else
			IsAboveLine := k1 <= k2
	end
end;

function IsBelowLine(x, y, x1, y1, x2, y2: real): boolean;
begin
	IsBelowLine := not IsAboveLine(x, y, x1, y1, x2, y2)
end;

function IsToTheRightOfALine(x, y, x1, y1, x2, y2: real): boolean;
begin
	if x1 = x2 then
		IsToTheRightOfALine := x >= x1
	else if x1 < x2 then
		IsToTheRightOfALine := IsBelowLine(x, y, x1, y1, x2, y2)
	else
		IsToTheRightOfALine := IsAboveLine(x, y, x2, y2, x1, y1)
end;

function IsInsideTriangle(x, y, x1, y1, x2, y2, x3, y3: real): boolean;
begin
	IsInsideTriangle :=
		IsToTheRightOfALine(x, y, x1, y1, x2, y2) and
		IsToTheRightOfALine(x, y, x2, y2, x3, y3) and
		IsToTheRightOfALine(x, y, x3, y3, x1, y1)
end;

function IsInsideDavidStar(x: real; y: real; var sh: Shape): boolean;
var
	a: real;
begin
	a := sqrt(3) * sh.r;
	IsInsideDavidStar :=
		IsInsideTriangle(
			x,          y,
			sh.x - a/2, sh.y - sh.r/2,
			sh.x,       sh.y + sh.r,
			sh.x + a/2, sh.y - sh.r/2
		) or
		IsInsideTriangle(
			x,          y,
			sh.x - a/2, sh.y + sh.r/2,
			sh.x + a/2, sh.y + sh.r/2,
			sh.x,       sh.y - sh.r
		)
end;

function IsInsideShape(x: real; y: real; var sh: Shape): boolean;
begin
	case sh.kind of
		CircleShape:
			IsInsideShape := IsInsideCircle(x, y, sh);
		DavidStarShape:
			IsInsideShape := IsInsideDavidStar(x, y, sh);
		else
			IsInsideShape := true;
	end
end;

procedure ShapeStep(var sh: Shape);
begin
	sh.x := sh.x + sh.dx;
	sh.y := sh.y + sh.dy;
	if (sh.x - sh.r < 1) or (sh.x + sh.r > sh.xmax) then
	begin
		sh.bumps := sh.bumps + 1;
		sh.dx := -sh.dx;
		if sh.x - sh.r < 1 then
			sh.x := 2 + 2*sh.r - sh.x
		else
			sh.x := 2*sh.xmax - 2*sh.r - sh.x
	end;
	if (sh.y - sh.r < 1) or (sh.y + sh.r > sh.ymax) then
	begin
		sh.bumps := sh.bumps + 1;
		sh.dy := -sh.dy;
		if sh.y - sh.r < 1 then
			sh.y := 2 + 2*sh.r - sh.y
		else
			sh.y := 2*sh.ymax - 2*sh.r - sh.y
	end
end;

procedure SetRect(var sh: Shape; var rect: Rectangle);
begin
	rect.x := max(floor((sh.x - sh.r)/XScale), 1 + 1);
	rect.w := min(ceil((sh.r * 2)/XScale) + 1, ScreenWidth - 1 - rect.x);
	rect.y := max(floor((sh.y - sh.r)/YScale), 1);
	rect.h := min(ceil((sh.r * 2)/YScale) + 1, ScreenHeight - rect.y)
end;

procedure RenderInRectangle(var sh: Shape; var rect: Rectangle);
var
	x, y: integer;
begin
	TextColor(Colors[1 + sh.bumps mod ColorCount]);
	for x := rect.x to rect.x + rect.w do
		for y := rect.y to rect.y + rect.h do
		begin
			{ GotoXY expects coordinates to be in the range 1..255 }
			GotoXY(x, y);
			if IsInsideShape(x*XScale, y*YScale, sh) then
				write('*')
			else
				write(' ')
		end;
	GotoXY(ScreenWidth, ScreenHeight);
end;

procedure ClearRect(var r: Rectangle);
var
	x, y: integer;
begin
	for x := r.x to r.x + r.w do
		for y := r.y to r.y + r.h do
		begin
			GotoXY(x, y);
			write(' ')
		end;
	GotoXY(ScreenWidth, ScreenHeight)
end;

procedure SetShapeDefaults(var sh: Shape);
begin
	sh.r := DefaultSize;
	sh.dx := DefaultVelocity;
	sh.dy := DefaultVelocity;
	sh.xmax := ScreenWidth * XScale;
	sh.ymax := ScreenHeight * YScale;
	sh.bumps := 0;
	sh.kind := DavidStarShape
end;

procedure ParseSize(var sh: Shape; s: string; var ok: boolean);
var
	i: integer;
label
	fail;
begin
	if length(s) < 1 then
		goto fail;
	sh.r := 0;
	for i := 1 to length(s) do
	begin
		if (s[i] < '0') or (s[i] > '9') then
			goto fail;
		sh.r := sh.r * 10 + ord(s[i]) - ord('0')
	end;
	exit;
fail:
	writeln('error: invalid size: ''', s, '''');
	ok := false
end;

procedure ParseType(var sh: Shape; s: string; var ok: boolean);
begin
	if s = 'circle' then
		sh.kind := CircleShape
	else if s = 'david' then
		sh.kind := DavidStarShape
	else
	begin
		writeln('error: unknown shape: ''', s, '''');
		ok := false
	end
end;

function StartsWith(s, p: string): boolean;
var
	i: integer;
begin
	if length(p) > length(s) then
	begin
		StartsWith := false;
		exit
	end;
	for i := 1 to length(p) do
		if s[i] <> p[i] then
		begin
			StartsWith := false;
			exit
		end;
	StartsWith := true
end;

function ChopOff(s: string; n: integer): string;
var
	i: integer;
	result: string = '';
begin
	if length(s) > n then
	begin
		SetLength(result, length(s) - n);
		for i := 1 to length(result) do
			result[i] := s[n + i]
	end;
	ChopOff := result
end;

procedure ArgParse(var sh: Shape; var ok: boolean);
var
	i: integer;
begin
	for i := 1 to ParamCount do
	begin
		if StartsWith(ParamStr(i), '-s') then
			ParseSize(sh, ChopOff(ParamStr(i), 2), ok)
		else if StartsWith(ParamStr(i), '-t') then
			ParseType(sh, ChopOff(ParamStr(i), 2), ok)
		else
		begin
			writeln('error: unexpected argument: ', ParamStr(i));
			writeln('usage: ', ParamStr(0), '[-sSHAPESIZE] [-t(circle|david)]');
			ok := false
		end;
		if not ok then
			exit
	end
end;

procedure CheckSize(var sh: Shape; var ok: boolean);
begin
	if ((sh.r + sh.dx)*2 > sh.xmax) or ((sh.r + sh.dy)*2 > sh.ymax) then
	begin
		writeln('error: shape too big');
		ok := false
	end
end;

procedure Setup(var sh: Shape; var ok: boolean);
begin
	SetShapeDefaults(sh);
	ArgParse(sh, ok);
	if not ok then
		exit;
	CheckSize(sh, ok);
	if not ok then
		exit;
	sh.x := 1 + sh.r;
	sh.y := 1 + sh.r
end;

procedure ClearScreen;
begin
	clrscr;
	write(#27'[0m')
end;

var
	sh: Shape;
	rect: Rectangle;
	quit: boolean = false;
	pause: boolean = false;
	setupOk: boolean = true;
begin
	Setup(sh, setupOk);
	if not setupOk then
		halt(1);
	ClearScreen;
	while true do
	begin
		HandleInput(quit, pause);
		if quit then
			break;
		SetRect(sh, rect);
		RenderInRectangle(sh, rect);
		delay(DelayDuration);
		ClearRect(rect);
		if pause then
			continue;
		ShapeStep(sh)
	end;
	ClearScreen
end.
