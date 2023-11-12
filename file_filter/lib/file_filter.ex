defmodule FileFilter do
  @general_file_path"lib/files/general_cc.txt"
  @local_file_path "lib/files/local_cc.csv"
  @moduledoc """
  Documentation for `FileFilter`.
  """

  def fetch_general_file(path \\ @general_file_path) do
    File.stream!(path)
    |> Stream.map(&String.trim/1)
    |> Stream.with_index()
    |> Stream.map(fn {line, _index} ->
      line
      |> String.split(" ")
      |> Enum.dedup()
    end)
    |> Stream.map(fn data ->
      list = data
      |> Enum.reject(&match?("", &1))
      [index: Enum.at(list, 0), cc: Enum.at(list, 1), mod_pay: Enum.at(list, 2)]
    end)
  end

  def fetch_local_file(path \\ @local_file_path) do
    File.stream!(path, [:utf8])
    |> Stream.map(&String.trim/1)
    |> Stream.with_index()
    |> Stream.map(fn {line, index} ->
      list = String.split(line, ",")
      [index: index, name: Enum.at(list, 1), cc: Enum.at(list, 2)]
    end)
  end

  def fetch_local_list_with_mod_pay(local_list, general_list) do
    local_list
    |> Enum.map(fn row ->
      case find_by_cc(row[:cc], general_list) do
        {:ok, list} -> Keyword.put(row, :mod_pay, Keyword.get(list, :mod_pay, "NOT CC"))
        :error -> Keyword.put(row, :mod_pay, "NO PAGO")
      end
    end)
  end

  def find_by_cc(cc, general_list) do
    item = general_list
    |> Enum.find(fn data -> data[:cc] == cc end)
    case item do
      nil -> :error
      item -> {:ok, item}
    end
  end

  def sort_by_peak_day(local_list) do
    local_list
    |> Enum.sort_by(&(&1[:peak_day]), :asc)
  end

  def get_last_digit_cc(nil), do: nil

  def get_last_digit_cc(cc) do
    list = String.graphemes(cc)
    Enum.at(list, length(list) - 1)
  end

  def define_peak_day(nil), do: "NO CC"
  def define_peak_day(last_digit) when last_digit in [0, 1], do: "Lunes"
  def define_peak_day(last_digit) when last_digit in [2, 3, 4], do: "Martes"
  def define_peak_day(last_digit) when last_digit in [5, 6, 7], do: "Miercoles"
  def define_peak_day(last_digit) when last_digit in [8, 9], do: "Jueves"


  def fetch_local_list_with_peak_day(local_list) do
    local_list
    |> Enum.map(fn data ->
      case get_last_digit_cc(data[:cc]) do
        nil -> data
        last_digit -> Keyword.put(data, :peak_day, define_peak_day(String.to_integer(last_digit)))
      end
    end)
  end

  def get_list_by_mod_pay(local_list, mod_pay) do
    local_list
    |> Enum.flat_map(fn data ->
      case data[:mod_pay] == mod_pay do
        true -> [data]
        false -> []
      end
    end)
  end

  def create_html_template(list_order, list_credit, list_non_pay) do
    "
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset=\"UTF-8\">
        </head>
        <body style=\"font-size: 10px\">
          <h1>MADRES TITULARES</h1>
          <p><strong>Madre lider: </strong> Ana Deiva Urrutia</p>
          <h2>Tabla para el modo de pago: GIRO</h2>
          <table style=\"font-size: 8px\">
            <thead>
              <tr>
                <th>No</th>
                <th>Nombre Completo</th>
                <th>Numero de cedula</th>
                <th>Modo de pago</th>
                <th>Dia de pago</th>
              </tr>
            </thead>
            <tbody>
            #{
              Enum.map(list_order, fn item ->
                "<tr>
                  <td>#{item[:index]}</td>
                  <td>#{item[:name]}</td>
                  <td>#{item[:cc]}</td>
                  <td>#{item[:mod_pay]}</td>
                  <td>#{item[:peak_day]}</td>
                </tr>"
              end)
            }
            </tbody>
          </table>

          <h2>Tabla para el modo de pago: ABONO A CUENTA CORRIENTE</h2>
          <table style=\"font-size: 8px\">
            <thead>
              <tr>
                <th>No</th>
                <th>Nombre Completo</th>
                <th>Numero de cedula</th>
                <th>Modo de pago</th>
              </tr>
            </thead>
            <tbody>
            #{
              Enum.map(list_credit, fn item ->
                "<tr>
                  <td>#{item[:index]}</td>
                  <td>#{item[:name]}</td>
                  <td>#{item[:cc]}</td>
                  <td>#{item[:mod_pay]}</td>
                </tr>"
              end)
            }
            </tbody>
          </table>

          <h2>Tabla para el modo de pago: NO PAGO</h2>
          <table style=\"font-size: 8px\">
            <thead>
              <tr>
                <th>No</th>
                <th>Nombre Completo</th>
                <th>Numero de cedula</th>
                <th>Modo de pago</th>
              </tr>
            </thead>
            <tbody>
            #{
              Enum.map(list_non_pay, fn item ->
                "<tr>
                  <td>#{item[:index]}</td>
                  <td>#{item[:name]}</td>
                  <td>#{item[:cc]}</td>
                  <td>#{item[:mod_pay]}</td>
                </tr>"
              end)
            }
            </tbody>
          </table>
        </body>
      </html>
    "
  end

  def generate_pdf() do
    general_list = fetch_general_file() |> Enum.to_list()
    local_list = fetch_local_file() |> Enum.to_list()

    list_order = local_list
      |> fetch_local_list_with_mod_pay(general_list)
      |> fetch_local_list_with_peak_day()
      |> sort_by_peak_day()
      |> get_list_by_mod_pay("GIRO")

    list_credit = local_list
      |> fetch_local_list_with_mod_pay(general_list)
      |> get_list_by_mod_pay("ABONO")

    list_non_pay = local_list
      |> fetch_local_list_with_mod_pay(general_list)
      |> get_list_by_mod_pay("NO PAGO")

    template = create_html_template(list_order, list_credit, list_non_pay)

    {:ok, filename}    = PdfGenerator.generate(template, page_size: "A5")
    {:ok, _pdf_content} = File.read(filename)
  end
end
