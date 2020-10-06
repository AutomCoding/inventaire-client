import should from 'should'
import _ from './utils_builder'

describe('Utils', () => {
  describe('cutBeforeWord', () => {
    const text = 'Lorem ipsum dolor sit amet, consectetur adipisicing elit'
    const result = _.cutBeforeWord(text, 24)
    it('should return a string shorter or egal to the limit', done => {
      (result.length <= 24).should.equal(true)
      done()
    })
    it('should cut between words', done => {
      result.should.equal('Lorem ipsum dolor sit')
      done()
    })
  })

  describe('get', () => {
    it('should get the property where asked', done => {
      _.get.should.be.a.Function()
      const obj = { a: { b: { c: 123 } }, d: 2 }
      _.get(obj, 'd').should.equal(2)
      _.get(obj, 'a.b.c').should.equal(123)
      done()
    })

    it("should return undefined if the value can't be accessed", done => {
      const obj = { a: { b: { c: 123 } }, d: 2 }
      should(_.get(obj, 'a.b.d')).not.be.ok()
      should(_.get(obj, 'nop.nop.nop')).not.be.ok()
      done()
    })
  })
})
