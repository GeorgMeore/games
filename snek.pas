program Snek;
uses CRT;

const
	DelayDuration = 128;

type
	Vec2 = array [0..1] of integer;
	SegmentPtr = ^Segment;
	Segment = record
		pos: Vec2;
		next: SegmentPtr;
	end;
	Snake = record
		first: SegmentPtr;
		second: SegmentPtr;
		last: SegmentPtr;
	end;
	Game = record
		snk: Snake;
		food: Vec2;
		vel: Vec2;
		quit: boolean;
		pause: boolean;
		failed: boolean;
	end;

procedure Vec2Set(var v: Vec2; x, y: integer);
begin
	v[0] := x; v[1] := y
end;

procedure Vec2Copy(var dst, src: Vec2);
begin
	dst[0] := src[0]; dst[1] := src[1]
end;

function Vec2Equal(var v1, v2: Vec2): boolean;
begin
	Vec2Equal := (v1[0] = v2[0]) and (v1[1] = v2[1])
end;

procedure ShowChar(var pos: Vec2; c: char);
begin
	GotoXY(pos[0], pos[1]);
	write(c);
	GotoXY(ScreenWidth, ScreenHeight)
end;

procedure HideChar(pos: Vec2);
begin
	GotoXY(pos[0], pos[1]);
	write(' ');
	GotoXY(ScreenWidth, ScreenHeight)
end;

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

procedure NewSegment(var sp: SegmentPtr; x, y: integer);
begin
	new(sp);
	Vec2Set(sp^.pos, x, y);
	sp^.next := nil
end;

function SnakeItersects(var s: Snake; var pos: Vec2; skipLast: boolean): boolean;
var
	sp: SegmentPtr;
begin
	sp := s.last;
	if skipLast then
		sp := sp^.next;
	while (sp <> nil) and not Vec2Equal(sp^.pos, pos) do
		sp := sp^.next;
	SnakeItersects := (sp <> nil)
end;

procedure InitSnake(var s: Snake);
begin
	NewSegment(s.first, 1, 1);
	s.last := s.first;
	s.second := nil
end;

procedure ResetSnake(var s: Snake);
var
	lastp: SegmentPtr;
begin
	while s.last <> s.first do
	begin
		lastp := s.last;
		s.last := s.last^.next;
		HideChar(lastp^.pos);
		dispose(lastp)
	end;
	s.second := nil
end;

procedure SnakeMoveTailToHead(var s: Snake);
var
	tmp: SegmentPtr;
begin
	if s.first = s.last then
		exit;
	s.second := s.first;
	tmp := s.last;
	s.last := tmp^.next;
	tmp^.next := nil;
	s.first^.next := tmp;
	s.first := tmp
end;

procedure SnakeAddNewHead(var s: Snake; var pos: Vec2);
var
	newHead: SegmentPtr;
begin
	NewSegment(newHead, pos[0], pos[1]);
	s.second := s.first;
	s.first^.next := newHead;
	s.first := newHead
end;

procedure GameAddFoodCell(var g: Game);
begin
	repeat
		Vec2Set(g.food, 1 + random(ScreenWidth - 1), 1 + random(ScreenHeight))
	until not SnakeItersects(g.snk, g.food, false);
	ShowChar(g.food, '#')
end;

procedure InitGame(var g: Game);
begin
	g.vel[0] := 1;
	g.vel[1] := 0;
	InitSnake(g.snk);
	GameAddFoodCell(g);
	g.quit := false;
	g.pause := false;
	g.failed := false
end;

procedure ResetGame(var g: Game);
begin
	ResetSnake(g.snk);
	g.failed := false;
end;

function ModAdd(a, b, lower, upper: integer): integer;
var
	result: integer;
begin
	result := a + b;
	if result < lower then
		result := upper - (lower - result - 1);
	if result > upper then
		result := lower + (result - upper - 1);
	ModAdd := result
end;

procedure CalcNextPosition(var curr, vel, result: Vec2);
begin
	result[0] := ModAdd(curr[0], vel[0], 1, ScreenWidth - 1);
	result[1] := ModAdd(curr[1], vel[1], 1, ScreenHeight)
end;

{ for debugging }
procedure PrintGameState(var g: Game; var nextPos: Vec2);
begin
	GotoXY(1, 1);
	writeln('head: (', g.snk.first^.pos[0], ' ', g.snk.first^.pos[1], ')');
	writeln('food: (', g.food[0], ' ', g.food[1], ')');
	writeln('vel: (', g.vel[0], ' ', g.vel[1], ')');
	writeln('next head position: (', nextPos[0], ' ', nextPos[1], ')');
	GotoXY(ScreenWidth, ScreenHeight)
end;

procedure GameStep(var g: Game);
var
	nextPos: Vec2;
begin
	ShowChar(g.snk.first^.pos, '*');
	CalcNextPosition(g.snk.first^.pos, g.vel, nextPos);
	ShowChar(nextPos, '@');
	if Vec2Equal(nextPos, g.food) then
	begin
		SnakeAddNewHead(g.snk, nextPos);
		GameAddFoodCell(g);
		exit
	end;
	if SnakeItersects(g.snk, nextPos, true) then
	begin
		g.failed := true;
		exit
	end;
	if not Vec2Equal(g.snk.last^.pos, nextPos) then
		HideChar(g.snk.last^.pos);
	SnakeMoveTailToHead(g.snk);
	Vec2Copy(g.snk.first^.pos, nextPos)
end;

function CanChangeDirection(snk: Snake; x, y: integer): boolean;
var
	newVel: Vec2;
	nextPos: Vec2;
begin
	if snk.second = nil then
	begin
		CanChangeDirection := true;
		exit
	end;
	Vec2Set(newVel, x, y);
	CalcNextPosition(snk.first^.pos, newVel, nextPos);
	CanChangeDirection := not Vec2Equal(snk.second^.pos, nextPos)
end;

procedure HandleInput(var g: Game);
var
	c: integer;
begin
	while KeyPressed do
	begin
		GetKey(c);
		case c of
			ord('j'):
				if CanChangeDirection(g.snk, 0, 1) then
					Vec2Set(g.vel, 0, 1);
			ord('k'):
				if CanChangeDirection(g.snk, 0, -1) then
					Vec2Set(g.vel, 0, -1);
			ord('h'):
				if CanChangeDirection(g.snk, -1, 0) then
					Vec2Set(g.vel, -1, 0);
			ord('l'):
				if CanChangeDirection(g.snk, 1, 0) then
					Vec2Set(g.vel, 1, 0);
			ord('q'):
				g.quit := true;
			ord('r'):
				ResetGame(g);
			ord(' '):
				g.pause := not g.pause
		end
	end
end;

var
	g: Game;
begin
	randomize;
	clrscr;
	InitGame(g);
	while not g.quit do
	begin
		if not g.pause and not g.failed then
			GameStep(g);
		delay(DelayDuration);
		HandleInput(g)
	end;
	clrscr
end.
