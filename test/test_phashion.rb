require 'helper'
require 'sqlite3'

class TestPhashion < Test::Unit::TestCase

  def split(hash)
    r = hash & 0xFFFFFFFF
    l = (hash >> 32) & 0xFFFFFFFF
    [l, r]
  end

  def test_db_bad_arg
    db = SQLite3::Database.new ':memory:'
    return unless db.respond_to? :enable_load_extension

    db.enable_load_extension true
    db.load_extension Phashion.so_file

    res = db.execute "SELECT hamming_distance('foo', 'bar', 'baz', 'zot')"
    assert_equal [[0]], res
  end

  def test_db_extension
    db = SQLite3::Database.new ':memory:'
    return unless db.respond_to? :enable_load_extension

    db.enable_load_extension true
    db.load_extension Phashion.so_file

    db.execute <<-eosql
  CREATE TABLE "images" (
    "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    "fingerprint_l" integer NOT NULL,
    "fingerprint_r" integer NOT NULL)
    eosql

    jpg = File.dirname(__FILE__) + '/jpg/Broccoli_Super_Food.jpg'
    png = File.dirname(__FILE__) + '/png/Broccoli_Super_Food.png'

    hash1 = Phashion.image_hash_for jpg
    hash2 = Phashion.image_hash_for png

    l, r = split hash1
    db.execute "INSERT INTO images (fingerprint_l, fingerprint_r) VALUES (#{l}, #{r})"

    expected = Phashion.hamming_distance hash1, hash2

    l, r = split hash2
    rows = db.execute "SELECT hamming_distance(fingerprint_l, fingerprint_r, #{l}, #{r}) FROM images"
    assert_equal expected, rows.first.first
  end

  def test_duplicate_detection
    files = %w(86x86-0a1e.jpeg 86x86-83d6.jpeg 86x86-a855.jpeg)
    images = files.map {|f| Phashion::Image.new("#{File.dirname(__FILE__) + '/../test/jpg/'}#{f}")}
    assert_duplicate images[0], images[1]
    assert_duplicate images[1], images[2]
    assert_duplicate images[0], images[2]
  end

  def test_duplicate_detection_2
    files = %w(b32aade8c590e2d776c24f35868f0c7a588f51e1.jpeg df9cc82f5b32d7463f36620c61854fde9d939f7f.jpeg e7397898a7e395c2524978a5e64de0efabf08290.jpeg)
    images = files.map {|f| Phashion::Image.new("#{File.dirname(__FILE__) + '/../test/jpg/'}#{f}")}
    assert_duplicate images[0], images[1]
    assert_duplicate images[1], images[2]
    assert_duplicate images[0], images[2]
  end

  def test_not_duplicate
    files = %w(86x86-0a1e.jpeg 86x86-83d6.jpeg 86x86-a855.jpeg avatar.jpg)
    images = files.map {|f| Phashion::Image.new("#{File.dirname(__FILE__) + '/../test/jpg/'}#{f}")}
    assert_not_duplicate images[0], images[3]
    assert_not_duplicate images[1], images[3]
    assert_not_duplicate images[2], images[3]
  end

  def test_multiple_types
    jpg = Phashion::Image.new(File.dirname(__FILE__) + '/jpg/Broccoli_Super_Food.jpg')
    png = Phashion::Image.new(File.dirname(__FILE__) + '/png/Broccoli_Super_Food.png')
    gif = Phashion::Image.new(File.dirname(__FILE__) + '/gif/Broccoli_Super_Food.gif')
    assert_duplicate jpg, png
    assert_duplicate gif, png
    assert_duplicate jpg, gif
  end
  
  def test_fingerprint_png_is_different
    png1 = Phashion::Image.new(File.dirname(__FILE__) + '/png/Broccoli_Super_Food.png')
    png2 = Phashion::Image.new(File.dirname(__FILE__) + '/png/linux.png')
    png3 = Phashion::Image.new(File.dirname(__FILE__) + '/png/grass.png')
    png4 = Phashion::Image.new(File.dirname(__FILE__) + '/png/Broccoli_Super_Food.png')
    
    fingerprints = []
    fingerprints << png1.fingerprint
    fingerprints << png2.fingerprint
    fingerprints << png3.fingerprint
    fingerprints << png4.fingerprint
    
    assert fingerprints.uniq.size == 3, "array should contain 3 unique fingerprints"
  end

  private

  def assert_duplicate(a, b)
    assert a.duplicate?(b), "#{a.filename} not dupe of #{b.filename}"
  end

  def assert_not_duplicate(a, b)
    assert !a.duplicate?(b), "#{a.filename} dupe of #{b.filename}"
  end  
end
