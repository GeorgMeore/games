program Invaders;

{ IDEA: write a small CRT replacement for VT100 }
uses crt;

const PlayerWidth = 5;
      PlayerHeight = 2;
      ShieldWidth = 15;
      ShieldHeight = 4;
      BulletWidth = 1;
      BulletHeight = 1;
      AlienWidth = 7;
      AlienHeight = 3;

const PlayerSprite =
	'  ^  ' +
	'#####' ;

const BulletSprite = '''';

const AlienSprite1 =
	' ##### ' +
	'##o#o##' +
	'\ \v/ /' ;

const AlienSprite2 =
	' ##### ' +
	'##o#o##' +
	'/ /v\ \' ;

const ShieldSprite =
	' ------------- ' +
	'---------------' +
	'---------------' +
	'---         ---' ;

const BannerHeight = 5;

{ IDEA: it would be fun to make a custom font format
        for this stuff with kerning etc }
type Banner = array[1..BannerHeight] of string;

const WonBanner: Banner = (
	'##   ##  #####   ##   ##    ##         ##  #####   ###    ##',
	' ## ##  ##   ##  ##   ##    ##   ###   ## ##   ##  ####   ##',
	'  ###   ##   ##  ##   ##     ## ## ## ##  ##   ##  ## ##  ##',
	'  ###   ##   ##  ##   ##     ## ## ## ##  ##   ##  ##  ## ##',
	'  ###    #####    #####       ###   ###    #####   ##   ####');

const LostBanner: Banner = (
	'##   ##  #####   ##   ##    ##      #####   ###### #########',
	' ## ##  ##   ##  ##   ##    ##     ##   ##  ##        ###   ',
	'  ###   ##   ##  ##   ##    ##     ##   ##  ######    ###   ',
	'  ###   ##   ##  ##   ##    ##     ##   ##      ##    ###   ',
	'  ###    #####    #####     ######  #####   ######    ###   ');

const PausedBanner: Banner = (
	'#######   ###    ##   ##  ######  ######  ###### ',
	'##   ##  ## ##   ##   ##  ##      ##      ##   ##',
	'####### #######  ##   ##  ######  ######  ##   ##',
	'##      ##   ##  ##   ##      ##  ##      ##   ##',
	'##      ##   ##   #####   ######  ######  ###### ');

type Entity = record
	sprite: string;
	width: byte;
	height: byte;
	x: integer;
	y: integer;
end;

type EntityPointer = ^Entity;

procedure initEntity(var ent: Entity;
                     sprite: string; w, h: byte; x, y: integer);
begin
	ent.sprite := sprite;
	ent.width := w;
	ent.height := h;
	ent.x := x;
	ent.y := y
end;

{ TODO: A more general `collides` function }
function hits(var bullet: Entity; var ent: Entity): boolean;
var
	a, b: integer;
begin
	a := bullet.x - ent.x + 1;
	b := ent.y - bullet.y + 1;
	if (a < 1) or (b < 1) or (a > ent.width) or (b > ent.height) then
		hits := false
	else
		hits := ent.sprite[a + (ent.height - b)*ent.width] <> ' '
end;

procedure hit(var bullet: Entity; var shield: Entity);
var
	a, b: integer;
begin
	a := bullet.x - shield.x + 1;
	b := shield.y - bullet.y + 1;
	shield.sprite[a + (shield.height - b)*shield.width] := ' '
end;


const GameDelay = 28;
      ShieldCount = 6;
      ShieldStep = 9;
      ShieldOffset = 3;
      ShieldsWidth = ShieldCount*ShieldWidth + (ShieldCount-1)*ShieldStep;
      PlayerFireDelay = 10;
      AliensFireChance = 0.05;
      AlienRows = 4;
      AlienCols = 9;
      AlienVStep = 1;
      AlienHStep = 3;
      AlienHShift = 3;
      AlienVShift = 3;
      AliensWidth = AlienCols*AlienWidth + (AlienCols-1)*AlienHStep;
      AliensHeight = AlienRows*AlienHeight + (AlienHStep-1)*AlienVStep;
      MinRows = PlayerHeight + ShieldOffset + ShieldHeight + AliensHeight;
      MinCols = ShieldsWidth + 2; { It is assumed that AliensWidth is smaller}
      MaxRows = 255;
      MaxCols = 255;


type BulletNode = record
	bullet: Entity;
	next: ^BulletNode
end;

type BulletList = ^BulletNode;

procedure addBullet(var bullets: BulletList; x, y: integer);
var
	node: ^BulletNode;
begin
	new(node);
	initEntity(node^.bullet, BulletSprite,
	           BulletWidth, BulletHeight,
	           x, y);
	node^.next := bullets;
	bullets := node
end;

procedure disposeBullets(var bullets: BulletList);
var
	next: ^BulletNode;
begin
	while bullets <> nil do
	begin
		next := bullets^.next;
		dispose(bullets);
		bullets := next
	end;
end;


type Direction = (Left, Right, Down);

type AliensState = record
	ents: array[1..AlienRows, 1..AlienCols] of Entity;
	row: integer;
	col: integer;
	dir: Direction;
	alive: array[1..AlienRows, 1..AlienCols] of boolean;
	bullets: BulletList;
	sprite1: string;
	sprite2: string;
	next: ^string;
end;

procedure nextAlien(var aliens: AliensState; var alien: EntityPointer);
var
	i, j: integer;
begin
	alien := nil;
	while aliens.row >= 1 do
	begin
		while aliens.col <= AlienCols do
		begin
			if alien <> nil then
				break;
			i := aliens.row;
			if (aliens.dir = Left) then
				j := aliens.col
			else
				j := AlienCols - aliens.col + 1;
			if aliens.alive[i][j] then
				alien := @aliens.ents[i][j];
			inc(aliens.col)
		end;
		if alien <> nil then
			break;
		dec(aliens.row);
		aliens.col := 1
	end
end;

function leftmostAlien(var aliens: AliensState): EntityPointer;
var
	i, j: integer;
begin
	for j := 1 to AlienCols do
		for i := 1 to AlienRows do
			if aliens.alive[i][j] then
			begin
				leftmostAlien := @aliens.ents[i][j];
				exit
			end;
	leftmostAlien := nil
end;

function rightmostAlien(var aliens: AliensState): EntityPointer;
var
	i, j: integer;
begin
	for j := AlienCols downto 1 do
		for i := 1 to AlienRows do
			if aliens.alive[i][j] then
			begin
				rightmostAlien := @aliens.ents[i][j];
				exit
			end;
	rightmostAlien := nil
end;

type PlayerState = record
	ent: Entity;
	delay: integer;
	bullets: BulletList
end;

type GameMode = (Playing, Won, Lost, Paused);

type GameState = record
	quit:  boolean;
	mode: GameMode;
	cols: integer;
	rows: integer;
	player: PlayerState;
	shields: array[1..ShieldCount] of Entity;
	aliens: AliensState
end;

procedure playerMoveLeft(var game: GameState);
begin
	if game.player.ent.x > 1 then
		dec(game.player.ent.x)
end;

procedure playerMoveRight(var game: GameState);
begin
	if game.player.ent.x <= game.cols - game.player.ent.width then
		inc(game.player.ent.x)
end;

procedure playerFire(var game: GameState);
begin
	if game.player.delay > 0 then
		exit;
	addBullet(game.player.bullets,
	          game.player.ent.x + game.player.ent.width div 2,
	          game.player.ent.y - game.player.ent.height + 1);
	game.player.delay := PlayerFireDelay
end;

procedure updatePlayerBullets(var game: GameState);
var
	next: ^BulletNode;
	pp: ^BulletList;
	i, j: integer;
label
	delete;
begin
	pp := @game.player.bullets;
	while pp^ <> nil do
	begin
		if pp^^.bullet.y <= 1 then
			goto delete;
		for i := 1 to ShieldCount do
			if hits(pp^^.bullet, game.shields[i]) then
			begin
				hit(pp^^.bullet, game.shields[i]);
				goto delete
			end;
		for i := 1 to AlienRows do
			for j := 1 to AlienCols do
				if game.aliens.alive[i][j] and
				   hits(pp^^.bullet, game.aliens.ents[i][j])
				then
				begin
					game.aliens.alive[i][j] := false;
					goto delete
				end;
		dec(pp^^.bullet.y);
		pp := @pp^^.next;
		continue;
delete:
		next := pp^^.next;
		dispose(pp^);
		pp^ := next
	end
end;

procedure updatePlayer(var game: GameState);
begin
	if game.player.delay > 0 then
		dec(game.player.delay);
	updatePlayerBullets(game)
end;

procedure aliensUpdateDirection(var aliens: AliensState; var game: GameState);
var
	ll, rr: EntityPointer;
	lx, rx: integer;
begin
	ll := leftmostAlien(aliens);
	rr := rightmostAlien(aliens);
	if (ll = nil) or (rr = nil) then
		exit;
	lx := ll^.x - AlienHShift;
	rx := rr^.x + AlienWidth + AlienHShift;
	case aliens.dir of
		Left:
			if lx < 1 then
				aliens.dir := Down;
		Right:
			if rx > game.cols then
				aliens.dir := Down;
		Down:
			if rx > game.cols then
				aliens.dir := Left
			else
				aliens.dir := Right
	end;
	if aliens.next = @aliens.sprite1 then
		aliens.next  := @aliens.sprite2
	else
		aliens.next  := @aliens.sprite1;
	aliens.col := 1;
	aliens.row := AlienRows
end;

procedure updateAliensBullets(var game: GameState);
var
	next: ^BulletNode;
	pp: ^BulletList;
	i: integer;
label
	delete;
begin
	pp := @game.aliens.bullets;
	while pp^ <> nil do
	begin
		if hits(pp^^.bullet, game.player.ent) then
		begin
			game.mode := Lost;
			exit
		end;
		if pp^^.bullet.y >= game.rows then
			goto delete;
		for i := 1 to ShieldCount do
			if hits(pp^^.bullet, game.shields[i]) then
			begin
				hit(pp^^.bullet, game.shields[i]);
				goto delete
			end;
		inc(pp^^.bullet.y);
		pp := @pp^^.next;
		continue;
delete:
		next := pp^^.next;
		dispose(pp^);
		pp^ := next
	end
end;

procedure updateAliens(var aliens: AliensState; var game: GameState);
var
	ap: ^Entity = nil;
begin
	updateAliensBullets(game);
	nextAlien(aliens, ap);
	if ap = nil then
	begin
		aliensUpdateDirection(aliens, game);
		nextAlien(aliens, ap)
	end;
	if ap = nil then
	begin
		game.mode := Won;
		exit
	end;
	ap^.sprite := aliens.next^;
	if random <= AliensFireChance then
		addBullet(aliens.bullets,
		          ap^.x + ap^.width div 2,
		          ap^.y);
	case aliens.dir of
		Left:  ap^.x := ap^.x - AlienHShift;
		Right: ap^.x := ap^.x + AlienHShift;
		Down:
			if ap^.y + AlienVShift >= game.rows - game.player.ent.height then
			begin
				ap^.y := game.rows;
				game.mode := Lost
			end
			else
			begin
				ap^.y := ap^.y + AlienVShift
			end
	end;
end;

procedure initGame(var game: GameState);
var
	i, j: integer;
begin
	game.cols := screenWidth;
	game.rows := screenHeight - 1; { The last row is reserved }
	game.quit := false;
	if (game.rows < MinRows) or (game.cols < MinCols) then
	begin
		writeln('Error: the screen is too small: ', game.rows, 'x', game.cols,
		        ' (min is ', MinRows, 'x', MinCols, ')');
		game.quit := true;
	end
	else if (game.rows > MaxRows) or (game.cols > MaxCols) then
	begin
		writeln('Error: the screen is too big: ', game.rows, 'x', game.cols,
		        ' (max is ', MaxRows, 'x', MaxCols, ')');
		game.quit := true;
	end;
	game.mode := Playing;
	initEntity(game.player.ent, PlayerSprite,
	           PlayerWidth, PlayerHeight,
	           1, game.rows);
	game.player.bullets := nil;
	game.player.delay := 0;
	for i := 1 to ShieldCount do
		if i = 1 then
			initEntity(game.shields[1], ShieldSprite,
			           ShieldWidth, ShieldHeight,
			           (game.cols - ShieldsWidth) div 2,
			           game.rows - game.player.ent.height - ShieldOffset)
		else
			initEntity(game.shields[i], ShieldSprite,
			           ShieldWidth, ShieldHeight,
			           game.shields[i-1].x + ShieldStep + ShieldWidth,
			           game.shields[i-1].y);
	for i := 1 to AlienRows do
		for j := 1 to AlienCols do
		begin
			{ TODO: death animation }
			game.aliens.alive[i][j] := true;
			initEntity(game.aliens.ents[i][1 + AlienCols - j], AlienSprite1,
			           AlienWidth, AlienHeight,
			           game.cols - j*AlienWidth - (j-1)*AlienHStep + 1,
			           i*AlienHeight + (i-1)*AlienVStep)
		end;
	game.aliens.col := 1;
	game.aliens.row := AlienRows;
	game.aliens.dir := Left;
	game.aliens.sprite1 := AlienSprite1;
	game.aliens.sprite2 := AlienSprite2;
	game.aliens.next := @game.aliens.sprite2;
	game.aliens.bullets := nil
end;

procedure restartGame(var game: GameState);
begin
	disposeBullets(game.player.bullets);
	disposeBullets(game.aliens.bullets);
	initGame(game)
end;

procedure updateGame(var game: GameState);
begin
	if game.mode <> Playing then
		exit;
	updatePlayer(game);
	if game.mode <> Playing then
		exit;
	updateAliens(game.aliens, game)
end;


procedure getKey(var code: integer);
var
	c: char;
begin
	c := ReadKey;
	if c = #0 then
		code := -ord(ReadKey)
	else
		code := ord(c)
end;

procedure handleInput(var game: GameState);
var
	c: integer = 0;
begin
	while KeyPressed do
	begin
		getKey(c);
		case c of
			ord('R'): restartGame(game);
			ord('q'): game.quit := true;
			ord('p'):
				if game.mode = Paused then
					game.mode := Playing
				else if game.mode = Playing then
					game.mode := Paused
		end;
		if game.mode <> Playing then
			continue;
		case c of
			ord('a'): playerMoveLeft(game);
			ord('d'): playerMoveRight(game);
			ord('s'): playerFire(game)
		end
	end
end;


{ We render to a buffer first instead of just writing directly to the screen
  for performance reasons. It's just faster. }
type Buffer = record
	chars: array[1..MaxRows, 1..MaxCols] of char;
	width: integer;
	height: integer
end;

procedure initBuffer(var buf: Buffer; width, height: integer);
var
	i, j: integer;
begin
	for i := 1 to height do
		for j := 1 to width do
			buf.chars[i][j] := ' ';
	buf.width := width;
	buf.height := height
end;

procedure showBuffer(var buf: Buffer);
var
	i, j: integer;
	row: string;
begin
	for i := 1 to buf.height do
	begin
		gotoXY(1, i);
		row := '';
		for j := 1 to buf.width do
			row := row + buf.chars[i][j];
		write(row)
	end;
	gotoXY(buf.width, buf.height + 1)
end;

procedure renderBanner(var buf: Buffer; var banner: Banner);
var
	i, j: integer;
	si, sj: integer;
begin
	si := (buf.height - BannerHeight) div 2;
	sj := (buf.width - length(banner[1])) div 2;
	for i := 1 to BannerHeight do
		for j := 1 to length(banner[i]) do
			buf.chars[si+i][sj+j] := banner[i][j]
end;

procedure renderEntity(var buf: Buffer; var ent: Entity);
var
	i, j: integer;
	c: char;
begin
	for i := 1 to ent.height do
		for j := 1 to ent.width do
		begin
			c := ent.sprite[(i-1)*ent.width + j];
			if c <> ' ' then
				buf.chars[ent.y - ent.height + i][ent.x + j - 1] := c
		end
end;

procedure renderBulletList(var buf: Buffer; bullets: BulletList);
begin
	while bullets <> nil do
	begin
		renderEntity(buf, bullets^.bullet);
		bullets := bullets^.next
	end;
end;

procedure render(var game: GameState);
var
	buf: Buffer;
	i, j: integer;
begin
	initBuffer(buf, game.cols, game.rows);
	renderEntity(buf, game.player.ent);
	for i := 1 to ShieldCount do
		renderEntity(buf, game.shields[i]);
	for i := 1 to AlienRows do
		for j := 1 to AlienCols do
			if game.aliens.alive[i][j] then
				renderEntity(buf, game.aliens.ents[i][j]);
	renderBulletList(buf, game.player.bullets);
	renderBulletList(buf, game.aliens.bullets);
	case game.mode of
		Lost:   renderBanner(buf, LostBanner);
		Won:    renderBanner(buf, WonBanner);
		Paused: renderBanner(buf, PausedBanner)
	end;
	showBuffer(buf)
end;


var
	game: GameState;
begin
	clrscr;
	randomize;
	initGame(game);
	while not game.quit do
	begin
		render(game);
		handleInput(game);
		updateGame(game);
		delay(GameDelay)
	end
end.
