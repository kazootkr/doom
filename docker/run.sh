#!/bin/sh
# doom 設定の隔離検証環境（Docker）のホスト側 wrapper
#
#   ./run.sh build                       イメージのビルド
#   ./run.sh batch [ELISP]               batch 検証（省略時は標準チェック）
#   ./run.sh screenshot [ELISP] [NAME]   GUI スクリーンショットを docker/out/NAME に保存
#   ./run.sh clean                       イメージ・パッケージキャッシュ volume の削除
#
# ELISP はコンテナ内の Emacs でのみ評価される（ホストでは実行されない）。
# コンテナ内シェルが必要な場合: ./run.sh build 済みの状態で
#   docker run --rm -it --entrypoint /bin/bash doom-verify
set -eu

cd "$(dirname "$0")"

IMAGE=doom-verify
LOCAL_VOLUME=doom-emacs-local

if ! docker info >/dev/null 2>&1; then
    echo "error: docker デーモンに接続できません。colima を起動してください: start-colima" >&2
    exit 1
fi

run_container() {
    mkdir -p out
    docker run --rm \
        -v "$(cd .. && pwd):/workspace/doom:ro" \
        -v "$LOCAL_VOLUME:/root/.config/emacs/.local" \
        -v "$(pwd)/out:/out" \
        "$IMAGE" "$@"
}

cmd="${1:-help}"
[ $# -gt 0 ] && shift

case "$cmd" in
    build)
        exec docker build -t "$IMAGE" -f Dockerfile ..
        ;;

    batch)
        run_container batch "$@"
        ;;

    screenshot)
        run_container screenshot "$@"
        echo "host path: $(pwd)/out/${2:-verify.png}"
        ;;

    clean)
        docker volume rm -f "$LOCAL_VOLUME"
        docker rmi -f "$IMAGE"
        ;;

    *)
        sed -n '2,11p' "$0"
        exit 2
        ;;
esac
