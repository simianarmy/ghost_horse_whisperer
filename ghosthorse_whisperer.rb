require 'optparse'
require 'escape'
require 'digest'
require 'twitter'
require "base64"

# ruby script to speak horse_js tweets
# and other stuff
#
INTERVALS   = 30
HANDLE      = 'horse_js'
HASHTAG     = 'HorseGhostMauger'
NEIGH_SOUND = './horseneigh.mp3'
MYK_SOUND   = './the-more-you-know.mp3'
SOUND_APP   = 'afplay'
last = nil
$cache = {}
$options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: ghosthorse_whisperer [options]"

  opts.on("-l", "--last", "Last tweet only") do |v|
    $options[:playLast] = v
  end
  opts.on("-v", "--verbose", "verbose") do |v|
    $options[:verbose] = v
  end
end.parse!

# Please don't abuse this - it's a read only app
Twitter.configure do |config|
  config.consumer_key = 'USzCMU7LF0Sg8ikOueRaig'
  config.consumer_secret = 'b08uSkkpfYjLIcrR5gDXgJI24y85gdTKkQ0efbYGGY'
  config.oauth_token = '54721863-mgTw6cDim71iLzgt3TPC4YRhAE4mVBizKIvEHKhKQ'
  config.oauth_token_secret = 'R6CkvGYcaDS7ZHj0XPgnTjauYaqlGlETK1sJXOAfjfs'
end

def speak(who, tweet)
    return unless tweet
    post_tag = nil

    # save last hash
    if tweet =~ /#(\S+)$/i
        post_tag = $1
    end
    # convert hashes
    if tweet =~ /#\S+/i
        tweet.gsub! /#(\S+)/, 'hash \1'
    end
    cmd = Escape.shell_command(["say", tweet])

    if who == HANDLE 
        `#{SOUND_APP} -v 0.3 #{NEIGH_SOUND}`
        `#{cmd}`
    else
        `#{cmd}`
        `#{SOUND_APP} #{MYK_SOUND}` if post_tag =~ /moreyouknow/i
    end
    puts cmd if $options[:verbose]
end

def gettags(tag)
    Twitter.search(tag, :result_type => "recent").results.map do |status|
        ["##{tag}", status.text]
      #"#{status.from_user}: #{status.text}"
    #tweets = `TWITTER search #{tag}`.map do |tweet|
        #tweet.split('#' + tag)
    end
end

def gethorse
    Twitter.user_timeline(HANDLE).map do |tweet|
    #`TWITTER search horse_js | grep ^horse_js`.map do |tweet|
        [HANDLE, tweet.text]
    end
end

def cache_key(val)
    Digest::MD5.hexdigest(val) unless val.nil?
end

# cache all messages
def cache_do(val)
    key = cache_key(val)
    if !$cache[key]
        yield if block_given?
        $cache[key] = 1
    end
end
    
while true do
    begin
        tweets = (gethorse + gettags(HASHTAG))
    rescue Twitter::Error::ClientError => e
        puts 'oh noes, client error ' + e
        sleep INTERVALS
        next
    end
    current = [] 

    puts 'all: ' + tweets.inspect if $options[:verbose]
    if $options[:playLast]
        current << tweets[0]
        $options[:playLast] = false
    else
        current = tweets.find_all { |t| !$cache[cache_key(t[1])] }
    end
    puts 'current: ' + current.inspect if $options[:verbose]

    current.each do |t| 
        cache_do(t[1]) do  
            speak t[0], t[1]
        end
    end

    # Cache all tweets now
    tweets.each { |t| cache_do(t[1]) }

    sleep INTERVALS 
end

