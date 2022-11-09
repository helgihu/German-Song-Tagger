#!/usr/bin/python3

import sys
import argparse
import pickle
import torch

from Data import Data
from RNNTagger import RNNTagger
from CRFTagger import CRFTagger


###########################################################################
# main function
###########################################################################

if __name__ == "__main__":

   parser = argparse.ArgumentParser(description='Annotation program of the RNN-Tagger.')

   parser.add_argument('path_param', type=str,
                       help='name of parameter file')
   parser.add_argument('path_data', type=str,
                       help='name of the file with input data')
   parser.add_argument('--crf_beam_size', type=int, default=10,
                       help='size of the CRF beam (if the system contains a CRF layer)')
   parser.add_argument('--gpu', type=int, default=0,
                       help='selection of the GPU (default is GPU 0)')
   parser.add_argument("--num_tags", type=int, default=1,
                       help="print that many best tags for each word")
   parser.add_argument("--min_prob_mass", type=float, default=0.0,
                       help="print the best tags until their total probability exceeds this threshold")
   parser.add_argument("--print_probs", action="store_true", default=False,
                       help="print the tag probabilities")

   args = parser.parse_args()

   device = torch.device('cpu')
   if args.gpu >= 0:
      if not torch.cuda.is_available():
         sys.exit('Sorry, no gpu available. Please drop the -gpu option.')
      if args.gpu >= torch.cuda.device_count():
         sys.exit('Sorry, the given gpu index was too large. Please choose a valid gpu index.')
      torch.cuda.set_device(args.gpu)
      device = torch.device('cuda')

   # load parameters
   data  = Data(args.path_param+'.io')   # read the symbol mapping tables

   with open(args.path_param+'.hyper', 'rb') as file:
      hyper_params = pickle.load(file)
   model = CRFTagger(*hyper_params) if len(hyper_params)==10 \
           else RNNTagger(*hyper_params)
   model.load_state_dict(torch.load(args.path_param+'.rnn'))
   model = model.to(device)

   if type(model) is CRFTagger:
      for optvar, option in zip((args.min_prob_mass, args.print_probs, args.num_tags),
                                ("min_prob_mass","print_probs","num_tags")):
         if optvar:
            print(f"Warning: Option --{option} is ignored because the model has a CRF output layer", file=sys.stderr)
   
   model.eval()
   with torch.no_grad():
      for i, words in enumerate(data.sentences(args.path_data)):
         print(i, end='\r', file=sys.stderr, flush=True)
   
         # map words to numbers and create Torch variables
         fwd_charIDs, bwd_charIDs = data.words2charIDvec(words)
         fwd_charIDs = torch.LongTensor(fwd_charIDs).to(device)
         bwd_charIDs = torch.LongTensor(bwd_charIDs).to(device)
         
         # optional word embeddings
         word_embs = None if data.word_emb_size==0 \
                     else torch.tensor(data.words2vecs(words)).to(device)
         
         # run the model
         if type(model) is RNNTagger:
            tagscores = model(fwd_charIDs, bwd_charIDs, word_embs)
            tagprobs = torch.nn.functional.softmax(tagscores, dim=-1)
            # print the best tags for each word
            for word, probs in zip(words, tagprobs):
               s, best_tagIDs, best_probs = 0.0, [], []
               values, indices = probs.sort(descending=True)
               for p, ID in zip(values, indices):
                  if s >= args.min_prob_mass and len(best_tagIDs) >= args.num_tags:
                     break
                  best_tagIDs.append(ID)
                  best_probs.append(p)
                  s += p
               best_tags = data.IDs2tags(best_tagIDs)
               if args.print_probs:
                  best_tags = [f"{t} {p}" for t, p in zip(best_tags, best_probs)]
               print(word, ' '.join(best_tags), sep="\t")
         elif type(model) is CRFTagger:
            tagIDs = model(fwd_charIDs, bwd_charIDs, word_embs)
            tags = data.IDs2tags(tagIDs)
            for word, tag in zip(words, tags):
               print(word, tag, sep='\t')
         else:
            sys.exit('Error')
   
   
         print('')
