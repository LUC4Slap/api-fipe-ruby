require 'sinatra'
require 'sinatra/reloader' if development?
require 'roo'
require 'json'
require 'prawn'
require 'prawn/table'

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

      # Limitar a leitura aos primeiros 50 registros
      max_rows = [sheet.last_row, 51].min # Incluindo a linha do cabeçalho

      # Iterar sobre as linhas (começando da segunda linha, pois a primeira é o cabeçalho)
      (2..max_rows).each do |row_num|
        row_data = {}

        headers.each_with_index do |header, index|
          value = sheet.cell(row_num, index + 1)
          # Remove o prefixo 'm' dos anos se existir
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

# Endpoint para listar todos os arquivos no diretório de uploads
get '/listar_arquivos' do
  # Verifica se o diretório de uploads existe
  if Dir.exist?(settings.upload_folder)
    # Lista todos os arquivos no diretório de uploads, excluindo '.' e '..'
    files = Dir.entries(settings.upload_folder).select { |f| !File.directory?(f) }

    content_type :json
    { arquivos: files }.to_json
  else
    status 404
    body "Diretório de uploads não encontrado!"
  end
end

# Gerar relatório em PDF com ajustes de layout
get '/gerar_relatorio' do
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

      # Preparar dados para inclusão no PDF
      data = []

      # Limitar a leitura aos primeiros 50 registros (51 com cabeçalho)
      max_rows = [sheet.last_row, 51].min

      # Iterar sobre as linhas (começando da segunda linha, pois a primeira é o cabeçalho)
      (2..max_rows).each do |row_num|
        row_data = {}

        headers.each_with_index do |header, index|
          value = sheet.cell(row_num, index + 1)
          # Remove o prefixo 'm' dos anos se existir
          header = header.to_s.gsub(/^m/, '') if header.is_a?(String)
          row_data[header] = value if value && !value.to_s.strip.empty?
        end

        data << row_data if row_data.any? # Adiciona apenas se houver dados na linha
      end

      # Gerar o PDF usando Prawn
      pdf = Prawn::Document.new(page_size: 'A4', page_layout: :landscape, compress: true)

      # Configurações de estilo
      pdf.font "Helvetica"

      # Título do relatório
      pdf.text "Relatório de Dados", size: 20, style: :bold
      pdf.move_down 20

      # Configurações da tabela
      table_data = [headers.map { |header| header.to_s.gsub(/^m/, '') }] + data.map(&:values)

      pdf.table(table_data, header: true, width: pdf.bounds.width) do
        # Estilo da primeira linha (cabeçalho)
        row(0).font_style = :bold
        row(0).background_color = 'AAAAAA'
        row(0).text_color = 'FFFFFF'

        # Estilo das células
        cells.padding = [5, 5, 5, 5]
        cells.size = 10

        # Borda das células
        cells.borders = [:top, :bottom, :left, :right]
        cells.border_width = 1
        cells.border_color = '999999'
      end

      # Salvar o PDF na pasta public
      public_pdf_path = "#{settings.public_folder}/relatorio_#{filename.gsub('.xlsx', '')}.pdf"
      pdf.render_file(public_pdf_path)

      # Retornar a URL do PDF gerado
      content_type :json
      { url: "#{request.base_url}/relatorio_#{filename.gsub('.xlsx', '')}.pdf" }.to_json
    else
      status 404
      body "Arquivo #{filename} não encontrado!"
    end
  end
end

