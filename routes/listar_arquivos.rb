require 'sinatra'

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
