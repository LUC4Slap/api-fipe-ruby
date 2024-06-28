require 'sinatra'
require 'sinatra/reloader' if development?
require 'roo'
require 'json'
require 'prawn'
require 'prawn/table'
require 'wicked_pdf'
require 'erb'
require 'fileutils'
require 'pg'

conn = PG.connect( 
  dbname: 'uploads',
  host: 'localhost',
  port: 5432,
  user: 'postgres',
  password: '123456'
)

set :public_folder, 'public'
set :views, 'views'
set :upload_folder, 'uploads'

# Helper para converter HTML para PDF
def html_to_pdf(html_content, output_path)
  Prawn::Document.generate(output_path, page_layout: :landscape, margin: [20, 20, 20, 20]) do |pdf|
    pdf.font "Helvetica"
    pdf.text html_content, inline_format: true
  end
end

COMPLEXITY_MAPPING = {
  1 => 'Simples',
  2 => 'Média',
  3 => 'Complexa',
  4 => 'Super Complexa'
}

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
    conn.exec("INSERT INTO caminho_arquivos (caminho) VALUES ('#{filepath}')")
    conn.close
    status 200
    body "Arquivo #{filename} foi carregado com sucesso!"
  else
    status 400
    body "Nenhum arquivo foi enviado!"
  end
end

# Listar arquivos do banco de dados
get '/listar_arquivos_db' do
  query = "SELECT * FROM caminho_arquivos"
  arquivos = []
  result = conn.exec(query)
  result.each do |row|
    arquivos << row['caminho']
  end
  # conn.close
  status 200
  content_type :json
  { data: arquivos }.to_json
end

# Endpoint para ler as linhas de um arquivo .xlsx
get '/ler_arquivo' do
  filename = params[:filename]
  sheet_number = params[:planilha]&.to_i
  filter_peso = params[:peso]&.to_f
  filter_complexidade = params[:complexidade]

  unless sheet_number
    sheet_number = 0
  end

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
      sheet = xlsx.sheet(sheet_number)

      # Extrair cabeçalhos
      headers = sheet.row(1)

      # Preparar dados para retorno
      data = []

      # Iterar sobre todas as linhas (começando da segunda linha, pois a primeira é o cabeçalho)
      (2..sheet.last_row).each do |row_num|
        row_data = {}

        headers.each_with_index do |header, index|
          value = sheet.cell(row_num, index + 1)
          # Remove o prefixo 'm' dos anos se existir
          header = header.to_s.gsub(/^m/, '') if header.is_a?(String)
          
          # teste
          if filter_peso.nil? || row_data['Peso'] == filter_peso
            if filter_complexidade.nil? || COMPLEXITY_MAPPING[row_data['Complexidade']] == COMPLEXITY_MAPPING[filter_complexidade]
              # Substituir o valor da complexidade pelo seu mapeamento numérico
              row_data['Complexidade'] = COMPLEXITY_MAPPING[row_data['Complexidade']]
              data << row_data if row_data.any? # Adiciona apenas se houver dados na linha
            end
          end
          # fim teste

          # row_data[header] = value
        end
        data << row_data 
      end

      content_type :json
      { data: data }.to_json
    else
      status 404
      body "Arquivo #{filename} não encontrado!"
    end
  end
end

get '/ler_arquivo_pge' do
  filename = params[:filename]
  sheet_number = params[:planilha]&.to_i

  unless sheet_number
    sheet_number = 0
  end

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
      sheet = xlsx.sheet(sheet_number)

      # Extrair cabeçalhos
      headers = sheet.row(1)

      # Preparar estrutura para contagem por anos e soma dos valores 0.0 e asteristicos
      years = headers.select { |header| header.is_a?(Integer) || (header.is_a?(String) && header.match?(/^\d{4}$/)) }
      counts_by_year = {}
      total_rows_minus_asterisks_zeros = {}

      # Inicializar hashes para contagem e total de linhas menos asteriscos e zeros
      years.each do |year|
        counts_by_year[year] = { asterisks: 0, zeros: 0 }
        total_rows_minus_asterisks_zeros[year] = sheet.last_row - 1  # Total de linhas menos o cabeçalho

        # Inicialmente subtrai a soma de asteriscos e zeros
        total_rows_minus_asterisks_zeros[year] -= counts_by_year[year][:asterisks]
        total_rows_minus_asterisks_zeros[year] -= counts_by_year[year][:zeros]
      end

      # Iterar sobre todas as linhas (começando da segunda linha, pois a primeira é o cabeçalho)
      (2..sheet.last_row).each do |row_num|
        headers.each_with_index do |header, index|
          value = sheet.cell(row_num, index + 1)
          next unless years.include?(header)

          # Atualizar contagem para o ano correspondente
          if value == "*****"
            counts_by_year[header][:asterisks] += 1
          elsif value.to_f == 0.0
            counts_by_year[header][:zeros] += 1
          end

          # Atualizar total de linhas menos asteriscos e zeros para o ano correspondente
          total_rows_minus_asterisks_zeros[header] -= 1 if value == "*****" || value.to_f == 0.0
        end
      end

      # Preparar dados finais no formato desejado
      data = []

      (2..sheet.last_row).each do |row_num|
        row_data = {}

        headers.each_with_index do |header, index|
          value = sheet.cell(row_num, index + 1)
          # Remove o prefixo 'm' dos anos se existir
          header = header.to_s.gsub(/^m/, '') if header.is_a?(String)
          row_data[header] = value if value && !value.to_s.strip.empty?
        end

        data << row_data if row_data.any? # Adiciona apenas se houver dados na linha
      end

      # Montar o resultado final para retorno
      result = {
        data: data,
        counts_by_year: counts_by_year.transform_values { |counts| counts.merge(total_rows_minus_asterisks_zeros: total_rows_minus_asterisks_zeros) }
      }

      content_type :json
      result.to_json
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

get '/gerar_relatorio' do
  filename = params[:filename]

  if filename.nil? || filename.empty?
    status 400
    body "Parâmetro 'filename' não especificado!"
  else
    filepath = "#{settings.upload_folder}/#{filename}"

    if File.exist?(filepath)
      xlsx = Roo::Spreadsheet.open(filepath)
      sheet = xlsx.sheet(0)

      @headers = sheet.row(1)
      @data = []
      max_rows = [sheet.last_row, 51].min

      (2..max_rows).each do |row_num|
        row_data = {}

        @headers.each_with_index do |header, index|
          value = sheet.cell(row_num, index + 1)
          header = header.to_s.gsub(/^m/, '') if header.is_a?(String)
          row_data[header] = value if value && !value.to_s.strip.empty?
        end

        @data << row_data if row_data.any?
      end

      html_content = erb :relatorio, layout: false

      output_path = "public/relatorio.pdf"
      pdf = WickedPdf.new.pdf_from_string(html_content)
      File.open(output_path, 'wb') do |file|
        file << pdf
      end

      status 200
      body "Relatório gerado com sucesso! Acesse o relatório em: /relatorio.pdf"
    else
      status 404
      body "Arquivo #{filename} não encontrado!"
    end
  end
end

# Ler catalo mil tec
# get '/ler_arquivo_catalogo' do
#   filename = params[:filename]
#   filter_peso = params[:peso]&.to_f
#   filter_complexidade = params[:complexidade] ? COMPLEXITY_MAPPING[params[:complexidade].to_i] : nil

#   # Verifica se o parâmetro filename foi fornecido
#   if filename.nil? || filename.empty?
#     status 400
#     body "Parâmetro 'filename' não especificado!"
#   else
#     filepath = "#{settings.upload_folder}/#{filename}"

#     # Verifica se o arquivo existe
#     if File.exist?(filepath)
#       # Ler o arquivo .xlsx usando roo
#       xlsx = Roo::Spreadsheet.open(filepath)
#       sheet = xlsx.sheet(0)

#       # Extrair cabeçalhos
#       headers = sheet.row(1)

#       # Preparar dados para retorno
#       data = []

#       # Iterar sobre todas as linhas (começando da segunda linha, pois a primeira é o cabeçalho)
#       (2..sheet.last_row).each do |row_num|
#         row_data = {}

#         headers.each_with_index do |header, index|
#           value = sheet.cell(row_num, index + 1)
#           row_data[header] = value if value && !value.to_s.strip.empty?
#         end

#         # Aplicar filtros se especificados
#         if (filter_peso.nil? || row_data['Peso'] == filter_peso) &&
#            (filter_complexidade.nil? || row_data['Complexidade'] == filter_complexidade)
#           data << row_data if row_data.any? # Adiciona apenas se houver dados na linha
#         end
#       end

#       content_type :json
#       { data: data }.to_json
#     else
#       status 404
#       body "Arquivo #{filename} não encontrado!"
#     end
#   end
# end

get '/ler_arquivo_catalogo' do
  filename = params[:filename]
  filter_peso = params[:peso]&.to_f
  filter_complexidade = params[:complexidade] ? COMPLEXITY_MAPPING[params[:complexidade].to_i] : nil

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

      # Iterar sobre todas as linhas (começando da segunda linha, pois a primeira é o cabeçalho)
      (2..sheet.last_row).each do |row_num|
        row_data = {}

        headers.each_with_index do |header, index|
          value = sheet.cell(row_num, index + 1)
          row_data[header] = value if value && !value.to_s.strip.empty?
        end

        # Aplicar filtros se especificados
        if (filter_peso.nil? || row_data['Peso'] == filter_peso) &&
           (filter_complexidade.nil? || row_data['Complexidade'] == filter_complexidade)
          data << row_data if row_data.any? # Adiciona apenas se houver dados na linha
        end
      end

      # Renderizar a tabela HTML
      erb :atividades, locals: { headers: headers, data: data }
    else
      status 404
      body "Arquivo #{filename} não encontrado!"
    end
  end
end

get '/teste_html' do
  erb :index
end