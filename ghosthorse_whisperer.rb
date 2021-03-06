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
HASHTAG     = 'horsemauger'
NEIGH_SOUND = 'horseneigh.mp3'
MYK_SOUND   = 'the-more-you-know.mp3'
HASH_SOUND_MAP = {
    'moreyouknow' => MYK_SOUND
}
HASH_VOICE_MAP = {
    HASHTAG => 'whisper'
}
SOUNDS_DIR  = Dir.pwd
SOUND_APP   = 'afplay'
$cache = {}
$options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: ghosthorse_whisperer [options]"

  opts.on("-v", "--verbose", "verbose") do |v|
    $options[:verbose] = v
  end
  opts.on("--last N", "Play last N tweets only") do |n|
    $options[:lastx] = n
  end
end.parse!

# TODO: read from external config
Twitter.configure do |config|
  config.consumer_key = ''
  config.consumer_secret = ''
  config.oauth_token = ''
  config.oauth_token_secret = ''
end

def speak(who, tweet)
    return unless tweet
    post_tag = nil
    who.gsub! /^#/, ''

    # save last hash
    if tweet =~ /#(\S+)$/i
        post_tag = $1
    end
    # convert hashes
    if tweet =~ /#\S+/i
        tweet.gsub! /#(\S+)/, 'hashtag \1'
    end

    cmd = ['say']
    if who == HANDLE 
        `#{SOUND_APP} -v 0.3 #{NEIGH_SOUND}`
    elsif HASH_VOICE_MAP[who]
        cmd << '-v'
        cmd << HASH_VOICE_MAP[who]
    end

    cmd << tweet
    puts cmd if $options[:verbose]

    `#{Escape.shell_command(cmd)}`
    play_hash_audio(post_tag) unless post_tag.nil? || who == HANDLE
end

# Checks hash audio map, plays audio if matched
def play_hash_audio(hash)
    HASH_SOUND_MAP.each do |k, v|
        `#{SOUND_APP} #{SOUNDS_DIR}/#{v}` if hash.downcase.match(k.downcase)
    end
end

def gettags(tag)
    Twitter.search(tag, :result_type => "recent").results.map do |status|
        ["##{tag}", status.text]
    end
end

def gethorse
    Twitter.user_timeline(HANDLE).map do |tweet|
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
        tweets = (gethorse + gettags(HASHTAG)).reverse
    rescue 
        puts 'oh noes, client error ' + $!
        sleep INTERVALS
        next
    end
    puts 'all: ' + tweets.inspect if $options[:verbose]
    current = tweets.find_all { |t| !$cache[cache_key(t[1])] }

    if $options[:lastx]
        current = current.pop $options[:lastx].to_i
        $options[:lastx] = false
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

