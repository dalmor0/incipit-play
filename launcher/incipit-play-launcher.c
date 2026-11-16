/*
 * Incipit Play · lançador (IncipitPlay.exe).
 *
 * O app de verdade (IncipitPlay-app.exe) carrega uns 300 MB de DLL do Qt antes de rodar a primeira linha; com o PC
 * apertado de memória, isso leva de segundos a quase um minuto sem nada na tela. Este lançador só usa o Windows: abre
 * na hora uma tela de abertura, garante uma cópia só do app e fecha a abertura quando a janela do app aparece.
 *
 * - Com argumentos (stream, list...), só repassa pro app e espera, sem abertura e sem trava de cópia única.
 * - Se o app já estiver aberto, traz a janela dele pra frente e sai.
 */
#define WIN32_LEAN_AND_MEAN
#define UNICODE
#define _UNICODE
#include <windows.h>
#include <wchar.h>

#define MUTEX_APP L"Local\\IncipitPlay-aberto"      /* o app segura este enquanto está aberto */
#define MUTEX_ABRINDO L"Local\\IncipitPlay-abrindo" /* o lançador segura este enquanto abre */
#define TITULO L"Incipit Play"

static DWORD pid_app = 0;
static HWND janela_abertura = NULL;
static HFONT fonte_titulo = NULL, fonte_apoio = NULL;
static int passo = 0;

typedef struct { DWORD pid; HWND achou; } Busca;

static BOOL CALLBACK procurar(HWND h, LPARAM lp)
{
	Busca *b = (Busca *)lp;
	DWORD pid = 0;
	wchar_t t[64];
	GetWindowThreadProcessId(h, &pid);
	if((b->pid == 0 || pid == b->pid) && IsWindowVisible(h) && h != janela_abertura)
	{
		GetWindowTextW(h, t, 64);
		if(wcsncmp(t, TITULO, 12) == 0)
		{
			b->achou = h;
			return FALSE;
		}
	}
	return TRUE;
}

static HWND janela_do_app(DWORD pid)
{
	Busca b = { pid, NULL };
	EnumWindows(procurar, (LPARAM)&b);
	return b.achou;
}

/* desenho: fundo grafite, a porta-I da Incipit em azul, o nome e uma linha de apoio */
static void desenhar(HDC dc, RECT *r)
{
	HBRUSH fundo = CreateSolidBrush(RGB(0x11, 0x13, 0x18));
	FillRect(dc, r, fundo);
	DeleteObject(fundo);
	HPEN borda = CreatePen(PS_SOLID, 1, RGB(0x2C, 0x31, 0x3B));
	HGDIOBJ antiga = SelectObject(dc, borda);
	SelectObject(dc, GetStockObject(NULL_BRUSH));
	Rectangle(dc, r->left, r->top, r->right, r->bottom);
	SelectObject(dc, antiga);
	DeleteObject(borda);

	/* porta-I (39,58 x 96 no desenho original), escala 0,5 */
	const int x0 = 40, y0 = 52;
	const double k = 0.5;
	HBRUSH azul_claro = CreateSolidBrush(RGB(0xCC, 0xE0, 0xFF));
	HBRUSH azul = CreateSolidBrush(RGB(0x7D, 0xB0, 0xFF));
	HBRUSH azul_escuro = CreateSolidBrush(RGB(0x3F, 0x6F, 0xD6));
	RECT topo = { x0, y0, x0 + (int)(39.58 * k), y0 + (int)(16.32 * k) };
	RECT base = { x0, y0 + (int)(79.68 * k), x0 + (int)(39.58 * k), y0 + (int)(96 * k) };
	FillRect(dc, &topo, azul_escuro);
	FillRect(dc, &base, azul_claro);
	POINT haste[] = {
		{ x0 + (int)(9.37 * k), y0 + (int)(79.68 * k) }, { x0 + (int)(9.37 * k), y0 + (int)(34.36 * k) },
		{ x0 + (int)(13.0 * k), y0 + (int)(24.0 * k) }, { x0 + (int)(19.79 * k), y0 + (int)(16.32 * k) },
		{ x0 + (int)(26.6 * k), y0 + (int)(24.0 * k) }, { x0 + (int)(30.21 * k), y0 + (int)(34.36 * k) },
		{ x0 + (int)(30.21 * k), y0 + (int)(79.68 * k) } };
	HGDIOBJ b0 = SelectObject(dc, azul);
	HGDIOBJ p0 = SelectObject(dc, GetStockObject(NULL_PEN));
	Polygon(dc, haste, 7);
	SelectObject(dc, b0);
	SelectObject(dc, p0);
	DeleteObject(azul_claro);
	DeleteObject(azul);
	DeleteObject(azul_escuro);

	SetBkMode(dc, TRANSPARENT);
	SetTextColor(dc, RGB(0xE7, 0xEA, 0xF0));
	SelectObject(dc, fonte_titulo);
	RECT rt = { x0 + 36, y0 - 4, r->right - 24, y0 + 40 };
	DrawTextW(dc, TITULO, -1, &rt, DT_LEFT | DT_SINGLELINE | DT_NOPREFIX);
	SetTextColor(dc, RGB(0xA0, 0xA7, 0xB4));
	SelectObject(dc, fonte_apoio);
	static const wchar_t *frases[] = { L"Abrindo", L"Abrindo.", L"Abrindo..", L"Abrindo..." };
	RECT ra = { x0 + 38, y0 + 34, r->right - 24, y0 + 60 };
	DrawTextW(dc, frases[passo % 4], -1, &ra, DT_LEFT | DT_SINGLELINE | DT_NOPREFIX);
}

static LRESULT CALLBACK proc(HWND h, UINT m, WPARAM w, LPARAM l)
{
	switch(m)
	{
		case WM_PAINT: {
			PAINTSTRUCT ps;
			HDC dc = BeginPaint(h, &ps);
			RECT r;
			GetClientRect(h, &r);
			desenhar(dc, &r);
			EndPaint(h, &ps);
			return 0;
		}
		case WM_TIMER:
			if(w == 1) { passo++; InvalidateRect(h, NULL, FALSE); }
			if(w == 2 && janela_do_app(pid_app)) PostQuitMessage(0);
			return 0;
		case WM_NCHITTEST:
			return HTCAPTION;   /* dá pra arrastar */
	}
	return DefWindowProcW(h, m, w, l);
}

static void carregar_fontes(const wchar_t *pasta)
{
	wchar_t ttf[MAX_PATH];
	swprintf(ttf, MAX_PATH, L"%ls\\fontes\\YoungSerif-Regular.ttf", pasta);
	int tem_serif = AddFontResourceExW(ttf, FR_PRIVATE, 0) > 0;
	swprintf(ttf, MAX_PATH, L"%ls\\fontes\\Archivo-Regular.ttf", pasta);
	int tem_archivo = AddFontResourceExW(ttf, FR_PRIVATE, 0) > 0;
	fonte_titulo = CreateFontW(-30, 0, 0, 0, FW_NORMAL, 0, 0, 0, DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0,
		tem_serif ? L"Young Serif" : L"Georgia");
	fonte_apoio = CreateFontW(-15, 0, 0, 0, FW_NORMAL, 0, 0, 0, DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0,
		tem_archivo ? L"Archivo" : L"Segoe UI");
}

int WINAPI wWinMain(HINSTANCE inst, HINSTANCE prev, PWSTR linha, int mostrar)
{
	(void)prev; (void)mostrar;
	wchar_t pasta[MAX_PATH], app[MAX_PATH], cmd[32768];
	GetModuleFileNameW(NULL, pasta, MAX_PATH);
	wchar_t *barra = wcsrchr(pasta, L'\\');
	if(barra) *barra = 0;
	swprintf(app, MAX_PATH, L"%ls\\IncipitPlay-app.exe", pasta);
	int com_argumentos = linha && *linha;
	swprintf(cmd, 32768, L"\"%ls\"%ls%ls", app, com_argumentos ? L" " : L"", com_argumentos ? linha : L"");

	STARTUPINFOW si = { sizeof(si) };
	PROCESS_INFORMATION pi;

	if(com_argumentos)
	{
		si.dwFlags = STARTF_USESTDHANDLES;
		si.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
		si.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
		si.hStdError = GetStdHandle(STD_ERROR_HANDLE);
		if(!CreateProcessW(app, cmd, NULL, NULL, TRUE, 0, NULL, pasta, &si, &pi))
			return 1;
		WaitForSingleObject(pi.hProcess, INFINITE);
		DWORD codigo = 0;
		GetExitCodeProcess(pi.hProcess, &codigo);
		return (int)codigo;
	}

	/* uma cópia só: se já está aberto (ou abrindo), traz pra frente e sai */
	HANDLE aberto = OpenMutexW(SYNCHRONIZE, FALSE, MUTEX_APP);
	HANDLE abrindo = CreateMutexW(NULL, TRUE, MUTEX_ABRINDO);
	if(aberto || GetLastError() == ERROR_ALREADY_EXISTS)
	{
		HWND h = NULL;
		for(int i = 0; i < 50 && !(h = janela_do_app(0)); i++)
			Sleep(100);
		if(h)
		{
			if(IsIconic(h)) ShowWindow(h, SW_RESTORE);
			SetForegroundWindow(h);
		}
		return 0;
	}

	carregar_fontes(pasta);
	WNDCLASSW wc = { 0 };
	wc.lpfnWndProc = proc;
	wc.hInstance = inst;
	wc.lpszClassName = L"IncipitPlayAbertura";
	wc.hCursor = LoadCursor(NULL, IDC_APPSTARTING);
	wc.hIcon = LoadIconW(inst, L"IDI_ICON1");
	RegisterClassW(&wc);
	const int w = 440, ht = 168;
	RECT area;
	SystemParametersInfoW(SPI_GETWORKAREA, 0, &area, 0);
	janela_abertura = CreateWindowExW(WS_EX_APPWINDOW, wc.lpszClassName, TITULO, WS_POPUP,
		area.left + (area.right - area.left - w) / 2, area.top + (area.bottom - area.top - ht) / 2, w, ht, NULL, NULL, inst, NULL);
	ShowWindow(janela_abertura, SW_SHOW);
	UpdateWindow(janela_abertura);

	if(!CreateProcessW(app, cmd, NULL, NULL, FALSE, 0, NULL, pasta, &si, &pi))
	{
		MessageBoxW(janela_abertura, L"Não achei o IncipitPlay-app.exe na pasta do Incipit Play. Reinstale o app.", TITULO, MB_ICONERROR);
		return 1;
	}
	pid_app = pi.dwProcessId;
	AllowSetForegroundWindow(pid_app);
	SetTimer(janela_abertura, 1, 400, NULL);
	SetTimer(janela_abertura, 2, 100, NULL);

	MSG msg;
	DWORD inicio = GetTickCount();
	for(;;)
	{
		while(PeekMessageW(&msg, NULL, 0, 0, PM_REMOVE))
		{
			if(msg.message == WM_QUIT) goto fim;
			TranslateMessage(&msg);
			DispatchMessageW(&msg);
		}
		/* o app fechou sem abrir janela, ou passou de 2 minutos: some com a abertura */
		if(WaitForSingleObject(pi.hProcess, 0) == WAIT_OBJECT_0 || GetTickCount() - inicio > 120000)
			break;
		MsgWaitForMultipleObjects(1, &pi.hProcess, FALSE, 100, QS_ALLINPUT);
	}
fim:
	DestroyWindow(janela_abertura);
	if(abrindo) { ReleaseMutex(abrindo); CloseHandle(abrindo); }
	CloseHandle(pi.hThread);
	CloseHandle(pi.hProcess);
	return 0;
}
