require 'sinatra'
require 'sinatra/reloader' if development?
require 'roo'
require 'json'
require 'prawn'
# require 'prawn/table'
require 'wicked_pdf'
require 'erb'
require 'fileutils'
require 'pg'

# conn = PG.connect(
#   dbname: 'uploads',
#   host: 'localhost',
#   port: 5432,
#   user: 'postgres',
#   password: '123456'
# )

set :public_folder, 'public'
set :views, 'views', Proc.new { File.join(root, "views") }
set :upload_folder, 'uploads'

# Requerer as rotas
Dir[File.join(__dir__, 'routes', '*.rb')].each { |file| require file }

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




# Listar arquivos do banco de dados
get '/listar_arquivos_db' do
  "Banco fora"
  # query = "SELECT * FROM caminho_arquivos"
  # arquivos = []
  # result = conn.exec(query)
  # result.each do |row|
  #   arquivos << row['caminho']
  # end
  # # conn.close
  # status 200
  # content_type :json
  # { data: arquivos }.to_json
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

get '/teste_html' do
  erb :index
end
