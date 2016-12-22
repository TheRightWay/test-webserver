require 'socket'
require 'uri'
require 'geokit'
require 'timezone'
class Server
  def initialize(host = 'localhost', port = '2345')
    @server = TCPServer.new(host, port)
    @cities = Hash.new

    Timezone::Lookup.config(:google) do |c|
      c.api_key = 'AIzaSyAbU5jTN1u4b3hHduhrfa0Tbz3L69y7rGQ'
    end

    @get_time_for = getZoneTimeByCity
    run
  end

  # Вытаскиваем время по городу
  # Изначально список городов был замыкаемой перменной с return, потому и лямбда
  def getZoneTimeByCity
    lambda {|city, time|
      if !@cities.include? city
        geolocation = Geokit::Geocoders::GoogleGeocoder.geocode(city)
        if geolocation.success?
          @cities[city] = Timezone.lookup(*geolocation.ll.split(','))
        else
          @cities[city] = nil
        end
      end
      @cities[city].nil? ? '' : @cities[city].time(time).strftime("#{city}: %Y-%m-%d %H:%M:%S \r\n")
    }
  end

  # Вызывает для каждого города блок
  def get_times(cities)
    # puts "Города в строке - #{cities}"
    res = "#{(time = Time.now.utc).strftime("UTC: %Y-%m-%d %H:%M:%S \r\n")}"
    res << cities.map do |city|

      @get_time_for[URI.decode(city), time]
    end.join if !cities.empty?
    res
  end

  # Проверка на правильнуй путь и передаём список городов, если он есть
  def set_response(params)
    params = params.split(" ")[1].split('?')
    res = ''
    if params[0] === '/time'
      params[1] ||=''

      res = get_times(params[1].split(','))
    end
    return res
  end

  def run
    loop {
      Thread.start(@server.accept) do | socket |
        request = socket.gets

        STDERR.puts request

        response = set_response(request)

        socket.print "HTTP/1.1 200 OK\r\n" +
                         "Content-Type: text/plain\r\n" +
                         "Content-Length: #{response.bytesize}\r\n" +
                         "Connection: close\r\n"

        socket.print "\r\n"
        socket.print response
        socket.close
        Thread.kill self
      end
    }.join
  end
end

server = Server.new('localhost', 2345)
