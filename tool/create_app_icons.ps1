Add-Type -AssemblyName System.Drawing

function Write-JapanIcon([int] $Size, [string] $Path) {
  $bitmap = [System.Drawing.Bitmap]::new($Size, $Size)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  try {
    $graphics.Clear([System.Drawing.Color]::White)
    $diameter = [int]($Size * 0.6)
    $offset = [int](($Size - $diameter) / 2)
    $brush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(188, 45, 55))
    try { $graphics.FillEllipse($brush, $offset, $offset, $diameter, $diameter) }
    finally { $brush.Dispose() }
    $bitmap.Save((Join-Path (Get-Location) $Path), [System.Drawing.Imaging.ImageFormat]::Png)
  }
  finally {
    $graphics.Dispose()
    $bitmap.Dispose()
  }
}

Write-JapanIcon 192 'web/icons/Icon-192.png'
Write-JapanIcon 192 'web/icons/Icon-maskable-192.png'
Write-JapanIcon 512 'web/icons/Icon-512.png'
Write-JapanIcon 512 'web/icons/Icon-maskable-512.png'
Write-JapanIcon 64 'web/favicon.png'
