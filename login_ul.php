<?php
declare(strict_types=1);
session_start();

/**
 * LDAP UL - LDAPS 636
 */
$LDAP_HOSTS = [
  "montet-dc1.ad.univ-lorraine.fr",
  "montet-dc2.ad.univ-lorraine.fr",
];
$LDAP_PORT = 636;
$BASE_DN_PERSONNELS = "OU=Personnels,OU=_Utilisateurs,OU=UL,DC=ad,DC=univ-lorraine,DC=fr";

$GROUP_PREFIX_IUTNC = "GGA_STP_FHB";
$GROUP_DEPT_INFO    = "GGA_STP_FHBAB";

function esc(string $s): string { return htmlspecialchars($s, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8'); }

function ldap_escape_filter(string $value): string {
  if (function_exists('ldap_escape')) return ldap_escape($value, '', LDAP_ESCAPE_FILTER);
  return str_replace(['\\','*','(',')',"\x00"], ['\\5c','\\2a','\\28','\\29','\\00'], $value);
}

// Petit check TCP pour diagnostiquer le firewall (port 636 bloqué = échec ici)
function tcp_check(string $host, int $port, int $timeoutSec = 3): array {
  $errno = 0; $errstr = '';
  $fp = @fsockopen($host, $port, $errno, $errstr, $timeoutSec);
  if ($fp) { fclose($fp); return [true, "OK"]; }
  return [false, "TCP FAIL ($errno) $errstr"];
}

function try_bind(array $hosts, int $port, string $login, string $password): array {
  $lastErr = "unknown error";
  foreach ($hosts as $h) {
    // Connexion LDAPS
    $uri = "ldaps://{$h}:{$port}";
    $conn = @ldap_connect($uri);
    if (!$conn) { $lastErr = "ldap_connect failed for $uri"; continue; }

    ldap_set_option($conn, LDAP_OPT_PROTOCOL_VERSION, 3);
    ldap_set_option($conn, LDAP_OPT_REFERRALS, 0);
    ldap_set_option($conn, LDAP_OPT_NETWORK_TIMEOUT, 5);

    $ok = @ldap_bind($conn, $login, $password);
    if ($ok) return [$conn, $h, null];

    $lastErr = ldap_error($conn);
    @ldap_unbind($conn);
  }
  return [null, null, $lastErr];
}

// Logout
if (isset($_GET['logout'])) {
  session_destroy();
  header("Location: login_ul.php");
  exit;
}

$error = null;
$diag  = [];
$user  = $_SESSION['ldap_user'] ?? null;

// Diagnostics réseau (utile tant que le ticket n’est pas appliqué partout)
foreach ($LDAP_HOSTS as $h) {
  [$ok, $msg] = tcp_check($h, $LDAP_PORT, 2);
  $diag[] = ["host" => $h, "tcp636" => $ok, "msg" => $msg];
}

// Traitement login
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
  $login = trim($_POST['login'] ?? '');
  $pass  = (string)($_POST['password'] ?? '');

  if ($login === '' || $pass === '') {
    $error = "Identifiant et mot de passe requis.";
  } elseif (!str_contains($login, '@')) {
    $error = "Format attendu: login@univ-lorraine.fr";
  } else {
    // Si TCP est bloqué partout, inutile d’insister
    $anyTcpOk = false;
    foreach ($diag as $d) if ($d["tcp636"]) { $anyTcpOk = true; break; }
    if (!$anyTcpOk) {
      $error = "Le port 636 (LDAPS) semble bloqué depuis ce poste/réseau (TCP KO sur dc1/dc2). "
             . "C’est typiquement un firewall. Référence ticket iTop: R-0125944 (VLAN 275, salle 503).";
    } else {
      [$conn, $usedHost, $bindErr] = try_bind($LDAP_HOSTS, $LDAP_PORT, $login, $pass);
      if (!$conn) {
        $error = "Échec d'authentification LDAP sur dc1/dc2. Détail: " . esc((string)$bindErr);
      } else {
        $safe = ldap_escape_filter($login);
        $filter = "(|(mail={$safe})(userPrincipalName={$safe}))";
        $attrs = ["displayName", "mail", "memberOf"];

        $sr = @ldap_search($conn, $BASE_DN_PERSONNELS, $filter, $attrs, 0, 5);
        if (!$sr) {
          $error = "Bind OK sur {$usedHost}, mais recherche LDAP échouée: " . esc(ldap_error($conn));
          @ldap_unbind($conn);
        } else {
          $entries = ldap_get_entries($conn, $sr);
          @ldap_unbind($conn);

          if (!is_array($entries) || ($entries['count'] ?? 0) < 1) {
            $error = "Bind OK sur {$usedHost}, mais aucune entrée trouvée dans la base Personnels.";
          } else {
            $e = $entries[0];
            $displayName = $e['displayname'][0] ?? '';
            $mail = $e['mail'][0] ?? $login;

            $memberOf = [];
            if (isset($e['memberof']) && is_array($e['memberof'])) {
              for ($i = 0; $i < ($e['memberof']['count'] ?? 0); $i++) $memberOf[] = $e['memberof'][$i];
            }

            $rattachements = array_values(array_filter($memberOf, fn($dn) => stripos($dn, $GROUP_PREFIX_IUTNC) !== false));
            $isIUTNC = false; $isDeptInfo = false;
            foreach ($rattachements as $dn) {
              if (stripos($dn, $GROUP_PREFIX_IUTNC) !== false) $isIUTNC = true;
              if (stripos($dn, $GROUP_DEPT_INFO) !== false) $isDeptInfo = true;
            }

            $_SESSION['ldap_user'] = [
              "server" => $usedHost,
              "displayName" => $displayName,
              "mail" => $mail,
              "rattachements" => $rattachements,
              "isIUTNC" => $isIUTNC,
              "isDeptInfo" => $isDeptInfo,
            ];
            header("Location: login_ul.php");
            exit;
          }
        }
      }
    }
  }
}

$user = $_SESSION['ldap_user'] ?? null;
?>
<!doctype html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Connexion LDAP UL (LDAPS 636)</title>
  <style>
    body{font-family:system-ui,Segoe UI,Roboto,Arial,sans-serif;background:#f6f7fb;margin:0}
    .wrap{max-width:820px;margin:40px auto;padding:0 16px}
    .card{background:#fff;border-radius:14px;padding:18px;box-shadow:0 10px 30px rgba(0,0,0,.08)}
    h1{margin:0 0 10px;font-size:20px}
    .row{display:grid;grid-template-columns:1fr 1fr;gap:14px}
    @media (max-width:720px){.row{grid-template-columns:1fr}}
    label{display:block;margin-top:10px;font-weight:650}
    input{width:100%;padding:10px 12px;margin-top:6px;border:1px solid #d7dbe7;border-radius:10px}
    button{margin-top:14px;padding:10px 14px;border:0;border-radius:10px;font-weight:750;cursor:pointer}
    .btn{background:#1a73e8;color:#fff}
    .btn2{background:#e8eaed}
    .box{border:1px solid #e4e7f0;border-radius:12px;padding:12px;background:#fafbff}
    .error{background:#ffe8e8;border:1px solid #ffb3b3;padding:10px 12px;border-radius:10px;color:#7a0b0b;margin:10px 0}
    .ok{background:#e9fff0;border:1px solid #b7f0c9;padding:10px 12px;border-radius:10px;color:#0c4a20}
    code{background:#f1f3f6;padding:2px 6px;border-radius:6px}
    ul{margin:6px 0 0 18px}
  </style>
</head>
<body>
<div class="wrap">
  <div class="card">
    <h1>Connexion LDAP UL (LDAPS 636)</h1>

    <div class="row">
      <div class="box">
        <strong>Diag réseau (port 636)</strong>
        <ul>
          <?php foreach ($diag as $d): ?>
            <li>
              <code><?= esc($d["host"]) ?></code> :
              <?= $d["tcp636"] ? "<span style='color:green;font-weight:700'>OK</span>" : "<span style='color:red;font-weight:700'>KO</span>" ?>
              <small>(<?= esc($d["msg"]) ?>)</small>
            </li>
          <?php endforeach; ?>
        </ul>
        <p style="margin:10px 0 0;color:#555">
          Si c’est <strong>KO</strong> ici, ton code n’y peut rien: c’est le firewall.
          Ticket: <code>R-0125944</code> (VLAN 275, salle 503, DACS).
        </p>
      </div>

      <div class="box">
        <?php if ($error): ?><div class="error"><?= $error ?></div><?php endif; ?>

        <?php if ($user): ?>
          <div class="ok">
            <div><strong>Connecté.</strong> Serveur: <code><?= esc($user["server"] ?? "") ?></code></div>
            <div>Nom: <?= esc($user["displayName"] ?: "(inconnu)") ?></div>
            <div>Mail: <?= esc($user["mail"] ?: "(inconnu)") ?></div>
            <div>Flags: IUTNC=<?= ($user["isIUTNC"] ? "true" : "false") ?> / DeptInfo=<?= ($user["isDeptInfo"] ? "true" : "false") ?></div>

            <div style="margin-top:10px;"><strong>memberOf filtré (<?= esc($GROUP_PREFIX_IUTNC) ?>*)</strong></div>
            <?php if (empty($user["rattachements"])): ?>
              <div>(aucun groupe correspondant)</div>
            <?php else: ?>
              <ul>
                <?php foreach ($user["rattachements"] as $dn): ?>
                  <li><code><?= esc($dn) ?></code></li>
                <?php endforeach; ?>
              </ul>
            <?php endif; ?>

            <p style="margin-top:12px;">
              <a href="login_ul.php?logout=1"><button class="btn2" type="button">Se déconnecter</button></a>
            </p>
          </div>
        <?php else: ?>
          <form method="post" autocomplete="off">
            <label for="login">Identifiant UL</label>
            <input id="login" name="login" type="email" placeholder="login@univ-lorraine.fr" required>

            <label for="password">Mot de passe</label>
            <input id="password" name="password" type="password" required>

            <button class="btn" type="submit">Se connecter</button>
          </form>
          <p style="margin-top:10px;color:#555">
            Bind en UPN (<code>login@univ-lorraine.fr</code>) puis recherche dans <code>OU=Personnels...</code>.
          </p>
        <?php endif; ?>
      </div>
    </div>

  </div>
</div>
</body>
</html>

