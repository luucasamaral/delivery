$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
$tsxPath = Join-Path $root 'packages/ui/src/dashboard.tsx'
$cssPath = Join-Path $root 'packages/ui/src/styles.css'
if (!(Test-Path $tsxPath) -or !(Test-Path $cssPath)) { throw 'Execute na raiz DELIVERY: dashboard.tsx ou styles.css nao encontrado.' }
$utf8 = New-Object System.Text.UTF8Encoding($false)
$tsx = [System.IO.File]::ReadAllText($tsxPath)
$css = [System.IO.File]::ReadAllText($cssPath)
if ($tsx.Contains('restaurant-picker-dropdown')) { throw 'O dropdown personalizado ja parece instalado. Nenhuma alteracao realizada.' }
if (!$tsx.Contains('import { useEffect, useRef, useState')) { throw 'Imports inesperados. Nenhuma alteracao realizada.' }
if (!$tsx.Contains('const searchRef = useRef<HTMLInputElement>(null);')) { throw 'Estado searchRef nao encontrado. Nenhuma alteracao realizada.' }
if (!$tsx.Contains('<div className="restaurant-picker">')) { throw 'Inicio do seletor nao encontrado. Nenhuma alteracao realizada.' }
$pattern = '(?s)      <div className="restaurant-picker">.*?(?=      <nav aria-label="Navega[^\r\n]*className="restaurant-menu")'
$regex = [regex]::new($pattern)
if ($regex.Matches($tsx).Count -ne 1) { throw "Bloco do seletor nao encontrado de forma unica ($($regex.Matches($tsx).Count)). Nenhuma alteracao realizada." }
$tsxNew = $tsx
$tsxNew = $tsxNew.Replace('ChefHat, ChevronDown,', 'ChefHat, Check, ChevronDown,')
if (!$tsxNew.Contains('ChefHat, Check, ChevronDown,')) { throw 'Nao foi possivel inserir o icone Check. Nenhuma alteracao realizada.' }
$states = @'
  const [restaurantMenuOpen, setRestaurantMenuOpen] = useState(false);
  const [restaurantSwitching, setRestaurantSwitching] = useState(false);
  const restaurantPickerRef = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (!restaurantMenuOpen) return;
    const onOutside = (event: PointerEvent) => {
      if (restaurantPickerRef.current && !restaurantPickerRef.current.contains(event.target as Node)) {
        setRestaurantMenuOpen(false);
      }
    };
    const onEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setRestaurantMenuOpen(false);
        restaurantPickerRef.current?.querySelector<HTMLButtonElement>(".restaurant-picker-trigger")?.focus();
      }
    };
    document.addEventListener("pointerdown", onOutside);
    document.addEventListener("keydown", onEscape);
    return () => {
      document.removeEventListener("pointerdown", onOutside);
      document.removeEventListener("keydown", onEscape);
    };
  }, [restaurantMenuOpen]);
'@
$tsxNew = $tsxNew.Replace('  const searchRef = useRef<HTMLInputElement>(null);', '  const searchRef = useRef<HTMLInputElement>(null);' + "`r`n" + $states)
$replacement = @'
      <div className={`restaurant-picker ${restaurantMenuOpen ? "is-open" : ""}`} ref={restaurantPickerRef}>
        <Store size={27} aria-hidden="true" />
        <div className="restaurant-picker-info">
          <span className="restaurant-picker-caption">Restaurante</span>
          <button
            type="button"
            className="restaurant-picker-trigger"
            aria-label={`Selecionar restaurante. Atual: ${member?.tenantName ?? "Nenhum"}`}
            aria-expanded={restaurantMenuOpen}
            aria-controls={restaurantMenuOpen ? "restaurant-picker-options" : undefined}
            disabled={busy || restaurantSwitching}
            onClick={() => setRestaurantMenuOpen(open => !open)}
          >
            <span className="restaurant-picker-name">{member?.tenantName ?? "Selecione seu restaurante"}</span>
            <ChevronDown size={16} className={restaurantMenuOpen ? "expanded" : ""} aria-hidden="true" />
          </button>
          <small>{branches.filter(b => b.active).length === 1 ? branches.find(b => b.active)?.name : `${branches.filter(b => b.active).length} unidades acessíveis`}</small>
        </div>
        {restaurantMenuOpen && (
          <div id="restaurant-picker-options" className="restaurant-picker-dropdown" role="group" aria-label="Restaurantes disponíveis">
            <div className="restaurant-picker-dropdown-title">Seus restaurantes</div>
            {session.memberships.map(m => {
              const isSelected = m.tenantId === session.tenantId;
              return (
                <button
                  key={m.tenantId}
                  type="button"
                  className={`restaurant-picker-option ${isSelected ? "selected" : ""}`}
                  aria-current={isSelected ? "true" : undefined}
                  disabled={busy || restaurantSwitching}
                  onClick={async () => {
                    if (isSelected) { setRestaurantMenuOpen(false); return; }
                    setRestaurantSwitching(true);
                    try {
                      await onTenant(m.tenantId);
                      navigate("overview");
                      setRestaurantMenuOpen(false);
                    } catch (error) {
                      console.error("Erro ao trocar restaurante:", error);
                    } finally {
                      setRestaurantSwitching(false);
                    }
                  }}
                >
                  <Store size={16} aria-hidden="true" />
                  <span className="restaurant-picker-option-name">{m.tenantName}</span>
                  {isSelected && <Check size={16} className="restaurant-picker-check" aria-hidden="true" />}
                </button>
              );
            })}
          </div>
        )}
      </div>
'@
$tsxNew = $regex.Replace($tsxNew, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $replacement + "`r`n" }, 1)
$cssBlock = @'

/* Mesa - dropdown personalizado do restaurante (v2) */
.restaurant-picker { position: relative; overflow: visible; }
.restaurant-picker-info { min-width: 0; }
.restaurant-picker-trigger { display: flex; align-items: flex-start; justify-content: space-between; gap: 8px; width: 100%; min-height: 24px; padding: 0; border: 0; background: transparent; color: #fff; text-align: left; cursor: pointer; font: inherit; }
.restaurant-picker-trigger:focus-visible { outline: 2px solid #a7dfb8; outline-offset: 4px; border-radius: 3px; }
.restaurant-picker-trigger:disabled { opacity: .6; cursor: wait; }
.restaurant-picker-trigger > svg { flex-shrink: 0; margin-top: 2px; color: #c8e5d1; transition: transform 160ms ease; }
.restaurant-picker-trigger > svg.expanded { transform: rotate(180deg); }
.restaurant-picker-dropdown { position: absolute; top: calc(100% + 8px); left: 0; right: 0; z-index: 100; padding: 7px; border: 1px solid #35634f; border-radius: 12px; background: #103b2e; box-shadow: 0 14px 30px #00180f80; max-height: 280px; overflow-y: auto; animation: restaurant-dropdown-in 150ms ease-out; }
.restaurant-picker-dropdown-title { padding: 7px 9px 9px; color: #a9c9b5; font-size: 10px; font-weight: 600; }
.restaurant-picker-option { display: flex; align-items: center; gap: 9px; width: 100%; padding: 11px 9px; border: 0; border-radius: 8px; background: transparent; color: #e7f5eb; text-align: left; cursor: pointer; font-size: 12px; }
.restaurant-picker-option:hover { background: #225441; }
.restaurant-picker-option.selected { background: #1d503d; color: #fff; }
.restaurant-picker-option:focus-visible { outline: 2px solid #a7dfb8; outline-offset: -2px; }
.restaurant-picker-option:disabled { opacity: .55; cursor: wait; }
.restaurant-picker-option-name { flex: 1; min-width: 0; overflow-wrap: anywhere; font-weight: 500; }
.restaurant-picker-check { flex-shrink: 0; color: #a7dfb8; }
@keyframes restaurant-dropdown-in { from { opacity: 0; transform: translateY(-5px); } to { opacity: 1; transform: translateY(0); } }
@media (prefers-reduced-motion: reduce) { .restaurant-picker-dropdown { animation: none; } .restaurant-picker-trigger > svg { transition: none; } }
'@
if ($css.Contains('dropdown personalizado do restaurante (v2)')) { throw 'CSS v2 ja instalado. Nenhuma alteracao realizada.' }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
Copy-Item $tsxPath "$tsxPath.bak-$stamp"
Copy-Item $cssPath "$cssPath.bak-$stamp"
[System.IO.File]::WriteAllText($tsxPath, $tsxNew, $utf8)
[System.IO.File]::WriteAllText($cssPath, $css + $cssBlock, $utf8)
Write-Host "Arquivos atualizados. Backups criados com sufixo .bak-$stamp" -ForegroundColor Green
Write-Host 'Executando typecheck...'
& pnpm --filter '@restaurant/dashboard' typecheck
if ($LASTEXITCODE -ne 0) { Write-Warning 'Typecheck falhou. Consulte o erro acima e restaure os backups se necessario.'; exit $LASTEXITCODE }
Write-Host 'Typecheck concluido. Agora pare o ambiente, compile e reinicie.' -ForegroundColor Green
