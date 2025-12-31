# Maintainer: Your Name <your_email@example.com>
pkgname=archmode
pkgver=0.2.0  # Update this based on your version
pkgrel=1
pkgdesc="A system mode manager for Arch Linux to toggle services for gaming, productivity, and more"
arch=('any')
url="https://github.com/theofficalnoodles/ArchMode"
license=('MIT')
depends=('bash' 'systemd')
optdepends=(
    'dunst: for notification management'
    'pulseaudio: for audio control'
    'pipewire: for audio control'
    'brightnessctl: for screen brightness control'
)
source=("${pkgname}-${pkgver}.tar.gz::${url}/archive/v${pkgver}.tar.gz")
sha256sums=('SKIP')  # Replace with actual checksum

package() {
    cd "${srcdir}/ArchMode-${pkgver}"
    
    # Install main script
    install -Dm755 archmode.sh "${pkgdir}/usr/bin/archmode"
    
    # Install systemd service
    install -Dm644 archmode.service "${pkgdir}/usr/lib/systemd/system/archmode.service"
    
    # Install license
    install -Dm644 LICENSE "${pkgdir}/usr/share/licenses/${pkgname}/LICENSE"
    
    # Install documentation
    install -Dm644 README.md "${pkgdir}/usr/share/doc/${pkgname}/README.md"
}
