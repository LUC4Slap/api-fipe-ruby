require 'sinatra'

# Endpoint para upload de arquivos
post '/upload' do
  if params[:file] && params[:file][:filename]
    filename = params[:file][:filename]
    file = params[:file][:tempfile]

    # Cria a pasta de uploads se não existir
    Dir.mkdir(settings.upload_folder) unless Dir.exist?(settings.upload_folder)

    # Salva o arquivo no diretório de uploads
    filepath = "#{settings.upload_folder}/#{filename}"
    File.open(filepath, 'wb') do |f|
      f.write(file.read)
    end
    # conn.exec("INSERT INTO caminho_arquivos (caminho) VALUES ('#{filepath}')")
    # conn.close
    status 200
    body "Arquivo #{filename} foi carregado com sucesso!"
  else
    status 400
    body "Nenhum arquivo foi enviado!"
  end
end
