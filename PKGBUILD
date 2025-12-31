# Maintainer: theofficalnoodles <khaledbuisness1@gmail.com>
pkgname=archmode
pkgver=1.0.0
pkgrel=1
pkgdesc="System Mode Manager for Arch Linux - Toggle services and features on/off"
arch=('any')
url="https://github.com/theofficalnoodles/archmode"
license=('MIT')
depends=('bash' 'systemd' 'coreutils')
optdepends=(
    'dunst: for notification management'
    'pulseaudio: for audio control'
    'brightnessctl: for brightness control'
    'nbfc: for fan control'
)
backup=("etc/archmode. conf")
source=("https://github.com/theofficalnoodles/archmode/archive/v${pkgver}.tar.gz")
md5sums=('SKIP')

build() {
    cd "${pkgname}-${pkgver}"
}

package() {
    cd "${pkgname}-${pkgver}"
    
    install -Dm755 archmode. sh "$pkgdir/usr/bin/archmode"
    install -Dm644 README.md "$pkgdir/usr/share/doc/archmode/README.md"
    install -Dm644 LICENSE "$pkgdir/usr/share/licenses/archmode/LICENSE"
    install -Dm644 archmode.service "$pkgdir/usr/lib/systemd/user/archmode.service"
}
