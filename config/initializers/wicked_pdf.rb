WickedPdf.config ||= {}

if RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
  WickedPdf.config = {
    exe_path: 'C:/Program Files/wkhtmltopdf/bin/wkhtmltopdf.exe' # Altere para o caminho correto
  }
else
  WickedPdf.config = {
    exe_path: '/usr/local/bin/wkhtmltopdf' # Verifique o caminho correto no seu sistema
  }
end