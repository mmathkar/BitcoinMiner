defmodule Bitcoinminer do
  use GenServer

  # Entry point to the code. 
  def main(args) do
   try do
      k = List.first(args) |> String.to_integer()
      Registry.start_link(:unique, Registry.BitcoinSpecs)
      start_link()
      Registry.register(Registry.BitcoinSpecs, "kzeroes", String.to_atom(Integer.to_string(k)))
      IO.inspect(Registry.lookup(Registry.BitcoinSpecs, "kzeroes"))
      str = k |> getKZeroes() |> spawnXminingThreadsServer()
      #mainMethod()
      
   rescue
      ArgumentError -> start_distributed(List.first(args))
   end
  end

  # Returns the IP address of the machine the code is being run on.
  def findIP do
    {ops_sys, _ } = :os.type
    ip = 
    case ops_sys do
     :unix -> {:ok, [addr: ip]} = :inet.ifget('en0', [:addr])
     to_string(:inet.ntoa(ip))
     :win32 -> {:ok, [ip, _]} = :inet.getiflist
     to_string(ip)
    end
    (ip)
  end
  
  # Load Balancer
    # called from get_k. matlab new worker joined and you gotta re-distribute the load
    # Try to equally divide the string size.
    # Keep a registry for load assigned ?
    # Try to maintain a map?
    # Store a range of size assigned to each worker.
  def loadBalancer do
    # Number of nodes connected (not counting self ) =   tuple_size(List.to_tuple(Node.list()))
    max_size = 100
    total_workers = tuple_size(List.to_tuple(Node.list())) + 1
    #workUnit = round(max_size/total_workers)
    workUnit = 10
    loop(List.to_tuple(Node.list()), total_workers - 2 , 0, workUnit, %{})
    end

    def loop(tuple, i, worker_max, workUnit, map) do
    # if(i>=0) do
    #     worker_min = worker_max + 1
    #     worker_max = worker_max + workUnit
    #     #IO.puts("For #{elem(tuple,i)}  Min Size = #{worker_min}     Max Size = #{worker_max}")
    #     map = Map.put(map, elem(tuple,i), {worker_max, worker_min})
    #     loop(tuple, i-1, worker_max, workUnit, map)
    #     #send elem(tuple,i), {[],[] }
    #     #sendToClient(elem(tuple,i), worker_min, worker_max)
    #     end

    # for x <- 0..i, do: (worker_min = (workUnit*x) +1
    #     worker_max = workUnit*(x+1)
    #     #IO.puts("For #{elem(tuple,i)}  Min Size = #{worker_min}     Max Size = #{worker_max}")
    #     map = Map.put(map, elem(tuple,x), {worker_max, worker_min}))
    # end

    {(workUnit*i)+1, workUnit*(i+1)}
    end

  # Returns a string with k zeroes
  def getKZeroes(k) do
   String.duplicate("0", k)
  end

  def mainMethod(k) do
  #IO.puts("In here..")
  getRandomStr()|>validateHash(k)
  mainMethod(k)
  end

  
  def getRandomStr do
  len =40
  salt = :crypto.strong_rand_bytes(len) |> Base.encode64 |> binary_part(0, len)
  "mmathkar" <> salt
  end

  
  def validateHash(inputStr,comparator) do
  hashVal=:crypto.hash(:sha256,inputStr) |> Base.encode16(case: :lower)
  bool = String.starts_with?(hashVal, comparator)
  if bool == true do
     printBitcoins(inputStr, hashVal)
  #  GenServer.cast({:TM, String.to_atom("muginu@"<>findIP())}, {:print_coin, inputStr, hashVal})
  end
  end

  # Prints found Bitcoins and their hash to the console.
  def printBitcoins(inputStr, hashVal) do
    IO.puts "#{inputStr}    #{hashVal}"
  end


### Server 

     def start_link() do
       IO.puts "In START LINK"
        unless Node.alive?() do
        #Registry.register(Registry.BitcoinSpecs, "kzeroes", String.to_atom(Integer.to_string(k)))
        local_node_name = String.to_atom("muginu@"<>findIP())
        {:ok, _} = Node.start(local_node_name)
        end
        Node.set_cookie(String.to_atom("monster"))
        GenServer.start_link(Bitcoinminer,[], name: :TM)
     end

    def print_coin(inputStr, hashValue) do
        [serverIP] = Registry.keys(Registry.ServerInfo, self())
        GenServer.cast({:TM, String.to_atom("muginu@"<>serverIP)}, {:print_coin, inputStr, hashValue})
    end

    def get_K do
        [serverIP] = Registry.keys(Registry.ServerInfo, self())
        GenServer.call({:TM, String.to_atom("muginu@"<>serverIP)}, :get_K)
    end

    #server side/callback func
    def init(_) do
      {:ok, Map.new}
    end

    def handle_call(:get_K, _from, map) do
      # CALL LOAD BALANCER HERE
      returnObj = loadBalancer()
      [{_, k}] = Registry.lookup(Registry.BitcoinSpecs, "kzeroes")
      {:reply, {returnObj, String.to_integer(Atom.to_string(k))}, map}
  end

    def handle_cast({:print_coin, inputStr, hashValue}, map) do
      case Map.get(map, inputStr) do
      nil ->
        printBitcoins(inputStr, hashValue)
        {:noreply, Map.put(map, inputStr, hashValue)}
      _ ->
        {:noreply, map}
    end
    end

### Client

   def start_distributed(ipAddr) do

   # store the IP
   Registry.start_link(:unique, Registry.ServerInfo)
   Registry.register(Registry.ServerInfo, ipAddr, :serverIP)

    unless Node.alive?() do
      local_node_name = String.to_atom("mmathkar"<>(:erlang.monotonic_time() |> :erlang.phash2(256) |> Integer.to_string(16))<>"@"<>findIP())
      {:ok, _} = IO.inspect(Node.start(local_node_name))
    end
   
    Node.set_cookie(String.to_atom("monster"))
    result = IO.inspect(Node.connect(String.to_atom("muginu@"<>ipAddr)))
    if result == true do
      {{max_val, min_val}, k} = IO.inspect(get_K())
      #{max_val, min_val} = Map.get(map, Node.self())
      #spawnXminingThreadsClient(String.duplicate("0", k), min_val, max_val)
      clientMainMethod(String.duplicate("0", k), min_val, max_val)
    end
  end

  def clientMainMethod(k, max_val, min_val) do
  getRandomStrClient(max_val, min_val)|>validateHashClient(k)
  clientMainMethod(k, max_val, min_val)
  end

  def getRandomStrClient(max_val, min_val) do
  #IO.puts("Found the range as #{max_val} - #{min_val}")
  len =Enum.random(min_val..max_val)
  salt = :crypto.strong_rand_bytes(len) |> Base.encode64 |> binary_part(0, len)
  "mmathkar" <> salt
  end

  def validateHashClient(inputStr,comparator) do
  hashVal=:crypto.hash(:sha256,inputStr) |> Base.encode16(case: :lower)
  bool = String.starts_with?(hashVal, comparator)
  if bool == true do
    print_coin(inputStr,hashVal)
  end
  end

def spawnXminingThreadsServer(k) do
    #IO.puts(count)
    spawn(Bitcoinminer,:mainMethod, [k])
    spawnXminingThreadsServer(k)
end

def spawnXminingThreadsClient(k, max_val, min_val) do
    #IO.puts(count)
    spawn(Bitcoinminer,:clientMainMethod, [k, max_val, min_val])
    spawnXminingThreadsClient(k, max_val, min_val)
end

  # defp generate_name(appname) do
  #   machine = Application.get_env(appname, :machine, "localhost") #Returns the value for :machine in app’s environment
  #   hex = :erlang.monotonic_time() |>
  #     :erlang.phash2(256) |>
  #     Integer.to_string(16)
  #   String.to_atom("#{appname}#{hex}@#{machine}")
  # end

  end