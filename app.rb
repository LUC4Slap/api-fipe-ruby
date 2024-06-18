require 'sinatra'
require 'sinatra/reloader' if development?
require 'roo'
require 'json'

set :public_folder, 'public'
set :upload_folder, 'uploads'

# Endpoint para verificar se a API está funcionando
get '/' do
  "API de Upload de Arquivos está funcionando!"
end

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

    status 200
    body "Arquivo #{filename} foi carregado com sucesso!"
  else
    status 400
    body "Nenhum arquivo foi enviado!"
  end
end

# Endpoint para ler as linhas de um arquivo .xlsx
get '/ler_arquivo' do
  filename = params[:filename]

  # Verifica se o parâmetro filename foi fornecido
  if filename.nil? || filename.empty?
    status 400
    body "Parâmetro 'filename' não especificado!"
  else
    filepath = "#{settings.upload_folder}/#{filename}"

    # Verifica se o arquivo existe
    if File.exist?(filepath)
      # Ler o arquivo .xlsx usando roo
      xlsx = Roo::Spreadsheet.open(filepath)
      sheet = xlsx.sheet(0)

      # Extrair cabeçalhos
      headers = sheet.row(1)

      # Preparar dados para retorno
      data = []

      # Iterar sobre as linhas (começando da segunda linha, pois a primeira é o cabeçalho)
      (2..sheet.last_row).each do |row_num|
        row_data = {}

        headers.each_with_index do |header, index|
          value = sheet.cell(row_num, index + 1)
          header = header.to_s.gsub(/^m/, '') if header.is_a?(String)
          row_data[header] = value if value && !value.to_s.strip.empty?
        end

        data << row_data if row_data.any? # Adiciona apenas se houver dados na linha
      end

      content_type :json
      { data: data }.to_json
    else
      status 404
      body "Arquivo #{filename} não encontrado!"
    end
  end
end
