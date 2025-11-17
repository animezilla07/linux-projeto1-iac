#!/usr/bin/env bash
# provision-iac.sh
# Script para criar usuários, grupos, diretórios e permissões conforme o desafio.
# Execute como root: sudo ./provision-iac.sh
set -euo pipefail

# Configurações (mude a senha padrão aqui, se quiser)
DEFAULT_PASSWORD="Senha123"   # senha inicial para todos (modifique antes de subir p/ produção)
EXPIRE_AT_FIRST_LOGIN=true    # se true força alteração da senha no primeiro login

# Listas (conforme enunciado)
DIRS=(/publico /adm /ven /sec)
GROUPS=(GRP_ADM GRP_VEN GRP_SEC)

# Usuários por grupo
USERS_GRP_ADM=(carlos maria joao_)
USERS_GRP_VEN=(debora sebastiana roberto)
USERS_GRP_SEC=(josefina amanda rogerio)

# Função útil: checar se grupo existe
group_exists() {
  getent group "$1" >/dev/null 2>&1
}

# Função: checar se usuário existe
user_exists() {
  id "$1" >/dev/null 2>&1
}

echo "=== Iniciando provisionamento IaC ==="

# 1) Remover usuários/grupos/diretórios do exercício (se existirem) -- cuidado: só remove os itens do enunciado
echo "--- Removendo usuários e grupos antigos (se existirem) ---"
for u in "${USERS_GRP_ADM[@]}" "${USERS_GRP_VEN[@]}" "${USERS_GRP_SEC[@]}"; do
  if user_exists "$u"; then
    echo "Removendo usuário $u"
    userdel -r "$u" || echo "Aviso: não foi possível remover home de $u ou já estava removido"
  fi
done

for g in "${GROUPS[@]}"; do
  if group_exists "$g"; then
    echo "Removendo grupo $g"
    groupdel "$g" || echo "Aviso: não foi possível remover grupo $g"
  fi
done

for d in "${DIRS[@]}"; do
  if [ -d "$d" ]; then
    echo "Removendo diretório $d"
    rm -rf "$d"
  fi
done

# 2) Criar grupos
echo "--- Criando grupos ---"
for g in "${GROUPS[@]}"; do
  if ! group_exists "$g"; then
    groupadd "$g"
    echo "Grupo $g criado"
  else
    echo "Grupo $g já existe"
  fi
done

# 3) Criar diretórios com dono root
echo "--- Criando diretórios ---"
for d in "${DIRS[@]}"; do
  mkdir -p "$d"
  chown root:root "$d"
done

# 4) Criar usuários, setar senha, forçar mudança de senha e adicionar ao grupo correspondente
echo "--- Criando usuários e atribuindo a grupos ---"
create_user() {
  local user="$1"
  local group="$2"

  # Remover possível underscore final no nome (joao_ -> joao_) -> manter exatamente como enunciado se quiser
  # Como o enunciado usa 'joao_' eu deixei literal; se preferir sem underscore altere aqui.
  if ! user_exists "$user"; then
    useradd -m -s /bin/bash -G "$group" -c "Usuário do grupo $group" "$user"
    echo "$user:$DEFAULT_PASSWORD" | chpasswd
    if [ "$EXPIRE_AT_FIRST_LOGIN" = true ]; then
      chage -d 0 "$user"
    fi
    echo "Usuário $user criado e adicionado ao grupo $group"
  else
    # Se já existe, apenas garanta que pertence ao grupo
    usermod -aG "$group" "$user"
    echo "Usuário $user já existe — adicionado ao grupo $group"
  fi
}

for u in "${USERS_GRP_ADM[@]}"; do create_user "$u" "GRP_ADM"; done
for u in "${USERS_GRP_VEN[@]}"; do create_user "$u" "GRP_VEN"; done
for u in "${USERS_GRP_SEC[@]}"; do create_user "$u" "GRP_SEC"; done

# 5) Permissões:
# - /publico : todos os usuários têm permissão total (rwx) -> chmod 777
# - /adm : somente grupo GRP_ADM tem rwx; owner root; outros sem permissão -> chmod 770, chown root:GRP_ADM
# - /ven : root:GRP_VEN, chmod 770
# - /sec : root:GRP_SEC, chmod 770

echo "--- Configurando permissões dos diretórios ---"
# /publico
chmod 777 /publico
echo "/publico -> chmod 777 (rwx para todos)"

# /adm
chown root:GRP_ADM /adm
chmod 770 /adm
echo "/adm  -> root:GRP_ADM 770 (rwx grupo, sem acesso para outros)"

# /ven
chown root:GRP_VEN /ven
chmod 770 /ven
echo "/ven  -> root:GRP_VEN 770"

# /sec
chown root:GRP_SEC /sec
chmod 770 /sec
echo "/sec  -> root:GRP_SEC 770"

# 6) Mensagem final e testes recomendados
echo "=== Provisionamento concluído ==="
echo "Usuários criados:"
for u in "${USERS_GRP_ADM[@]}" "${USERS_GRP_VEN[@]}" "${USERS_GRP_SEC[@]}"; do
  if user_exists "$u"; then
    echo " - $u"
  fi
done

echo ""
echo "Teste rápido sugerido:"
echo " - su - carlos  (senha padrão: $DEFAULT_PASSWORD)"
echo " - cd /adm && touch teste.txt"
echo " - su - debora  && cd /adm && ls -la /adm  (deve dar 'Permission denied')"
echo ""
echo "Lembrete: altere a DEFAULT_PASSWORD no script antes de rodar em produção, ou use gerenciamento de chaves."
