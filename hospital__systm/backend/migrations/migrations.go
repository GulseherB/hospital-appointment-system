// Package migrations, SQL migration dosyalarını ikili dosyaya gömer.
// Böylece golang-migrate dosya yoluna (boşluklu klasör adları dahil) bağımlı kalmaz.
package migrations

import "embed"

//go:embed *.sql
var FS embed.FS
